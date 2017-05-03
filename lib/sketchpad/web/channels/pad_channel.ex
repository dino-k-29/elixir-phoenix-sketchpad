defmodule Sketchpad.Web.PadChannel do
  @moduledoc """
  """
  use Sketchpad.Web, :channel

  alias Phoenix.Socket.Broadcast
  alias Sketchpad.Pad
  alias Sketchpad.Web.{Endpoint, Presence}


  def broadcast_png_outsource(pad_id, ref) do
    priv_topic = topic(pad_id) <> ":" <> ref
    Endpoint.broadcast(priv_topic, "generate_png", %{})
  end

  def broadcast_stroke(from, pad_id, user_id, stroke) do
    Endpoint.broadcast_from!(from, topic(pad_id), "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def broadcast_clear(from, pad_id) do
    Endpoint.broadcast_from!(from, topic(pad_id), "clear", %{})
  end

  defp topic(pad_id), do: "pad:#{pad_id}"

  def join("pad:" <> pad_id, %{"user_agent" => agent}, socket) do
    {:ok, server} = Pad.find(pad_id)
    send self(), {:after_join, agent}

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:server, server)

    {:ok, socket}
  end

  def handle_info({:after_join, agent}, socket) do
    server = socket.assigns.server

    {:ok, ref} = Presence.track(socket, socket.assigns.user_id, %{user_agent: agent})
    socket.endpoint.subscribe(socket.topic <> ":" <> ref)

    push socket, "presence_state", Presence.list(socket)

    for {user_id, %{strokes: strokes}} <- Pad.render(server) do
      for stroke <- Enum.reverse(strokes) do
        push socket, "stroke", %{user_id: user_id, stroke: stroke}
      end
    end

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "generate_png"}, socket) do
    push socket, "generate_png", %{}
    {:noreply, socket}
  end

  def handle_in("png", %{"img" => "data:image/png;base64," <> img}, socket) do
    {:ok, ascii} = Pad.img_to_ascii(img)
    IO.puts ascii
    IO.puts ">>#{socket.assigns.user_id}"
    {:reply, :ok, socket}
  end

  def handle_in("stroke", data, socket) do
    %{pad_id: pad_id, user_id: user_id, server: server} = socket.assigns
    :ok = Pad.put_stroke(self(), server, pad_id, user_id, data)
    {:noreply, socket}
  end

  def handle_in("clear", _params, socket) do
    %{server: server, pad_id: pad_id} = socket.assigns
    :ok = Pad.clear(self(), server, pad_id)
    {:reply, :ok, socket}
  end

  def handle_in("new_msg", %{"body" => body}, socket) do
    broadcast! socket, "new_msg", %{
      user_id: socket.assigns.user_id,
      body: body
    }
    {:reply, :ok, socket}
  end
end