defmodule TaskOverlordDemo.Overlord do
  @moduledoc false

  defstruct [
    :pid,
    :ref,
    :base_encoded_ref,
    :mfa,
    :heading,
    :message,
    :status,
    :logs,
    :started_at,
    :finished_at,
    :expires_at_unix
  ]

  @type status() :: :running | :streaming | :completed | :discarded | :error
  @type beam_task_info() :: {pid(), reference(), mfa()}

  @type t() :: %__MODULE__{
          pid: pid(),
          ref: reference(),
          base_encoded_ref: String.t(),
          mfa: {module(), atom(), [any()]},
          heading: Module.t() | String.t(),
          message: String.t(),
          status: status(),
          logs: [{Logger.level(), String.t()}],
          started_at: DateTime.t(),
          finished_at: DateTime.t() | nil,
          expires_at_unix: integer()
        }

  @default_timeout :timer.minutes(1)
  @discard_interval :timer.seconds(30)

  def default_timeout, do: @default_timeout
  def discard_interval, do: @discard_interval

  @spec pub_sub_topic(module :: module()) :: String.t()
  def pub_sub_topic(module),
    do: module |> Module.split() |> Enum.map_join(":", &Macro.underscore/1)

  defguard is_overlord?(value)
           when is_struct(value, __MODULE__) and
                  map_size(value) > 0

  @doc """
  Creates a new Overlord struct from a Beam task info tuple and additional information.

  The `beam_task_info` should be a tuple containing `{pid, ref, mfa}`.
  The `info` map must contain at least `:heading` and `:message` keys.
  If `opts` are provided, they can include `:status`, `:logs`, `:started_at`, `:finished_at`, and `:expires_at_unix`.
  """
  @spec make(beam_task_info(), map(), keyword()) :: t()
  def make(beam_task, info, opts \\ [])

  def make({pid, ref, mfa}, info, opts) do
    {heading, message} = get_heading_and_message(info)

    %__MODULE__{
      pid: pid,
      ref: ref,
      base_encoded_ref: encode_ref(ref),
      mfa: mfa,
      heading: heading,
      message: message,
      status: Keyword.get(opts, :status, :running),
      logs: Keyword.get(opts, :logs, []),
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      finished_at: Keyword.get(opts, :finished_at, nil),
      expires_at_unix: Keyword.get(opts, :expires_at_unix, default_expiration())
    }
  end

  def make(_beam_task_info, info, _opts) do
    raise ArgumentError,
          """
          Expected info to be a map, got: #{inspect(info)}. 

          Please provide a map with at least :heading and :message.
          """
  end

  @spec decode_ref(reference()) :: String.t()
  def decode_ref(encoded_ref) do
    encoded_ref |> Base.url_decode64!(padding: false) |> :erlang.binary_to_term()
  end

  @spec expired?(__MODULE__.t()) :: boolean
  def expired?(%__MODULE__{expires_at_unix: expiration}) do
    DateTime.to_unix(DateTime.utc_now()) > expiration
  end

  def expired?(_), do: false

  @spec get_heading_and_message(map()) :: {String.t(), String.t()}
  defp get_heading_and_message(attrs) do
    if is_nil(attrs) or attrs == %{} do
      raise ArgumentError,
            "Attributes cannot be nil or empty. Please provide a map of attributes."
    end

    if is_nil(Map.get(attrs, :heading)) do
      raise ArgumentError, "Heading cannot be nil. Please provide a heading."
    end

    if is_nil(Map.get(attrs, :message)) do
      raise ArgumentError, "Message cannot be nil. Please provide a message."
    end

    {Map.get(attrs, :heading), Map.get(attrs, :message)}
  end

  @spec default_expiration() :: integer
  defp default_expiration do
    DateTime.utc_now() |> DateTime.add(:timer.minutes(5), :millisecond) |> DateTime.to_unix()
  end

  @spec encode_ref(reference()) :: String.t()
  defp encode_ref(ref) do
    ref
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end
end
