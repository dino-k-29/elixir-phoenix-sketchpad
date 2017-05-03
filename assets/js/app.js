import "phoenix_html"
import {Socket, Presence} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"

let App = {
  init(userId, userToken){
    this.presences = {}
    this.el       = document.getElementById("sketchpad")
    this.messages = document.getElementById("messages")
    this.users = document.getElementById("users")
    this.msgInput = document.getElementById("message-input")
    this.clearButton = document.getElementById("clear-button")
    this.exportButton = document.getElementById("export-button")

    this.pad = new Sketchpad(this.el, userId)
    window.pad = this.pad

    this.socket = new Socket("/socket", {
      params: {token: userToken}
    })
    this.socket.connect()
    this.padChannel = this.socket.channel("pad:lobby", {user_agent: navigator.userAgent})

    this.pad.on("stroke", data => {
      this.padChannel.push("stroke", data)
    })

    this.exportButton.addEventListener("click", () => {
      window.open(this.pad.getImageURL())
    })

    this.padChannel.on("stroke", ({user_id, stroke}) => {
      this.pad.putStroke(user_id, stroke, {color: "#000000"})
    })

    this.padChannel.on("clear", () => this.pad.clear())

    this.clearButton.addEventListener("click", e => {
      this.pad.clear()
      this.padChannel.push("clear")
    })

    this.msgInput.addEventListener("keypress", e => {
      if(e.keyCode !== 13){ return }
      let body = this.msgInput.value

      this.msgInput.disabled = true
      let onOk = () => {
        this.msgInput.value = ""
        this.msgInput.disabled = false
        this.msgInput.focus()
      }
      let onError = () => { this.msgInput.disabled = false }

      this.padChannel.push("new_msg", {body: body})
        .receive("ok", onOk)
        .receive("error", onError)
        .receive("timeout", onError)
    })

    this.padChannel.on("new_msg", ({user_id, body}) => {
      this.messages.innerHTML +=
        `<br/><b>${sanitize(user_id)}:</b> ${sanitize(body)}`
      this.messages.scrollTop = this.messages.scrollHeight
    })

    let onJoin = (user_id, current, newPresence) => {
      if(!current){
        console.log(`${user_id} has joined`)
      } else {
        console.log(`${user_id} has opened a new tab`)
      }
    }

    let onLeave = (user_id, current, leftPresence) => {
      if(current.metas.length === 0){
        console.log(`${user_id} has left`)
      } else {
        console.log(`${user_id} has closed a tab`)
      }
    }

    this.padChannel.on("presence_state", state => {
      this.presences = Presence.syncState(this.presences, state, onJoin, onLeave)
      this.renderUsers(this.users, this.presences)
    })

    this.padChannel.on("presence_diff", diff => {
      this.presences = Presence.syncDiff(this.presences, diff, onJoin, onLeave)
      this.renderUsers(this.users, this.presences)
    })

    this.padChannel.on("generate_png", () => {
      this.padChannel.push("png", {img: this.pad.getImageURL()})
    })
    this.padChannel.join()
      .receive("ok", resp => console.log("joined!", resp))
      .receive("error", reason => console.log("err!", reason))
  },

  renderUsers(container, presences){
    let users = Presence.list(presences, (user_id, {metas: [first, ...rest]}) => {
      return {agent: first.user_agent, id: user_id, count: rest.length + 1}
    })
    console.log(users)
    container.innerHTML = users.map(user => {
      return `<br/>${user.id} (${user.count})`
    }).join("")
  }
}

App.init(window.userId, window.userToken)