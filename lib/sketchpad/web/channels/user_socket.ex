defmodule Sketchpad.Web.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "pad:*", Sketchpad.Web.PadChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket, timeout: 45_000
  # transport :longpoll, Phoenix.Transports.LongPoll

  require Logger
  def connect(%{"token" => token}, socket) do
    case Phoenix.Token.verify(socket, "user token", token, max_age: 120_000) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, reason} ->
        Logger.debug "failed to connect: #{inspect reason}"
        :error
    end
  end

  def id(socket), do: nil
end