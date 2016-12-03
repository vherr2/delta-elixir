defmodule Slab.Tandem.Op do
  def compose(a, b) do
    size = min(op_len(a), op_len(b))
    { op1, a } = take(a, size)
    { op2, b } = take(b, size)
    { compose_atomic(op1, op2), a, b }
  end

  defp compose_atomic(a = %{ :retain => length }, b = %{ :retain => _ }) do
    case Slab.Tandem.Attr.compose(a[:attributes], b[:attributes], true) do
      false -> %{ :retain => length }
      attr -> %{ :retain => length, :attributes => attr }
    end
  end

  defp compose_atomic(a = %{ :insert => insert }, b = %{ :retain => _ }) do
    case Slab.Tandem.Attr.compose(a[:attributes], b[:attributes]) do
      false -> %{ :insert => insert }
      attr -> %{ :insert => insert, :attributes => attr }
    end
  end

  defp compose_atomic(%{ :retain => _ }, b = %{ :delete => _ }), do: b
  defp compose_atomic(_, _), do: false

  def merge(%{ :delete => left }, %{ :delete => right }) do
    %{ :delete => left + right }
  end

  def merge(op1 = %{ :insert => left }, op2 = %{ :insert => right }) when is_bitstring(left) and is_bitstring(right) do
    cond do
      is_nil(op1[:attributes]) and is_nil(op2[:attributes]) ->
        %{ :insert => left <> right }
      op1[:attributes] == op2[:attributes] ->
        %{ :insert => left <> right, :attributes => op1[:attributes] }
      true ->
        false
    end
  end

  def merge(op1 = %{ :retain => left }, op2 = %{ :retain => right }) do
    cond do
      is_nil(op1[:attributes]) and is_nil(op2[:attributes]) ->
        %{ :retain => left + right }
      op1[:attributes] == op2[:attributes] ->
        %{ :retain => left + right, :attributes => op1[:attributes] }
      true ->
        false
    end
  end

  def merge(a, b), do: false

  defp take(op = %{ :insert => text }, length) when is_bitstring(text) do
    case String.length(text) - length do
      0 -> { op, [] }
      _ ->
        { left, right } = String.split_at(text, length)
        case op do
          %{ :attributes => attr } ->
            { %{ :insert => left, :attributes => attr }, [%{ :insert => right, :attributes => attr }] }
          _ ->
            { %{ :insert => left }, [%{ :insert => right }] }
        end
    end
  end

  defp take(op = %{ :insert => _ }, _length) do
    { op, [] }
  end

  defp take(op = %{ :retain => op_length }, take_length) do
    case op_length - take_length do
      0 -> { op, [] }
      rest ->
        case op do
          %{ :attributes => attr } ->
            { %{ :retain => take_length, :attributes => attr }, [%{ :retain => rest, :attributes => attr }] }
          _ ->
            { %{ :retain => take_length }, [%{ :retain => rest }] }
        end
    end
  end

  defp take(op = %{ :delete => op_length }, take_length) do
    case op_length - take_length do
      0 -> { op, [] }
      rest -> { %{ :delete => take_length }, [%{ :delete => rest }] }
    end
  end

  defp op_len(%{ :insert => text }) when is_bitstring(text), do: String.length(text)
  defp op_len(%{ :insert => _ }), do: 1
  defp op_len(%{ :retain => len }), do: len
  defp op_len(%{ :delete => len }), do: len
end
