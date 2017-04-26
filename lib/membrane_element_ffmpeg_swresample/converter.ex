defmodule Membrane.Element.FFmpeg.SWResample.ConverterOptions do
  defstruct \
    source_caps: %Membrane.Caps.Audio.Raw{}
end

defmodule Membrane.Element.FFmpeg.SWResample.Converter do
  use Membrane.Element.Base.Filter
  alias Membrane.Caps.Audio.Raw, as: Caps
  alias Membrane.Element.FFmpeg.SWResample.ConverterNative
  alias Membrane.Element.FFmpeg.SWResample.ConverterOptions
  alias Membrane.Element.FFmpeg.SWResample.SerializedFormat

  def_known_source_pads %{
    :sink => {:always, [
      %Caps{format: :f64le},
      %Caps{format: :f32le},
      %Caps{format: :s32le},
      %Caps{format: :u32le},
      %Caps{format: :s16le},
      %Caps{format: :u16le},
      %Caps{format: :s8},
      %Caps{format: :u8},
    ]}
  }

  def_known_sink_pads %{
    :source => {:always, [
      %Caps{format: :f64le},
      %Caps{format: :f32le},
      %Caps{format: :s32le},
      %Caps{format: :u32le},
      %Caps{format: :s16le},
      %Caps{format: :u16le},
      %Caps{format: :s8},
      %Caps{format: :u8},
    ]}
  }

  def handle_init %ConverterOptions{source_caps: source_caps} do
    {:ok, %{source_caps: source_caps, native: nil}}
  end

  def handle_caps(
    :sink,
    %Caps{format: sink_format, sample_rate: sink_rate, channels: sink_channels} = sink_caps,
    %{source_caps: %Caps{format: src_format, sample_rate: src_rate, channels: src_channels} = src_caps} = state
  ) do
    case ConverterNative.create(
      sink_format |> SerializedFormat.from_atom, sink_rate, sink_channels,
      src_format |> SerializedFormat.from_atom, src_rate, src_channels
    ) do
      {:ok, native} -> {:ok, [{:caps, {:source, src_caps}}], %{state | native: native}}
      {:error, reason} -> {:error, reason, state}
    end
  end

  def handle_buffer :sink, _caps, %Membrane.Buffer{}, %{native: nil} do
    {:error, "FFmpeg swresample: native uninitialized, initialzation has failed or received no/invalid caps"}
  end
  def handle_buffer :sink, _caps, %Membrane.Buffer{payload: payload} = buffer, %{native: native} = state do
    case ConverterNative.convert native, payload do
      {:ok, <<>>} -> {:ok, state}
      {:ok, result} -> {:ok, [{:send, {:source, %Membrane.Buffer{buffer | payload: result}}}], state}
      {:error, desc} -> {:error, desc}
    end
  end

end
