defmodule BlockScoutWeb.SmartContractView do
  use BlockScoutWeb, :view

  alias Explorer.Chain

  def queryable?(inputs) when not is_nil(inputs), do: Enum.any?(inputs)

  def queryable?(inputs) when is_nil(inputs), do: false

  def writable?(function) when not is_nil(function),
    do:
      !constructor?(function) && !event?(function) &&
        (payable?(function) || nonpayable?(function))

  def writable?(function) when is_nil(function), do: false

  def outputs?(outputs) when not is_nil(outputs), do: Enum.any?(outputs)

  def outputs?(outputs) when is_nil(outputs), do: false

  defp event?(function), do: function["type"] == "event"

  defp constructor?(function), do: function["type"] == "constructor"

  def payable?(function), do: function["stateMutability"] == "payable" || function["payable"]

  def nonpayable?(function) do
    if function["type"] do
      function["stateMutability"] == "nonpayable" ||
        (!function["payable"] && !function["constant"] && !function["stateMutability"])
    else
      false
    end
  end

  def address?(type), do: type in ["address", "address payable"]
  def int?(type), do: String.contains?(type, "int") && !String.contains?(type, "[")

  def named_argument?(%{"name" => ""}), do: false
  def named_argument?(%{"name" => nil}), do: false
  def named_argument?(%{"name" => _}), do: true
  def named_argument?(_), do: false

  def values_with_type(value, type) when is_list(value) do
    cond do
      String.starts_with?(type, "tuple") ->
        values =
          value
          |> tuple_array_to_array(type)
          |> Enum.join(", ")

        render_array_type_value(type, values)

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map(&to_string(&1))
          |> Enum.join(", ")

        render_array_type_value(type, values)

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        render_array_type_value(type, values)

      true ->
        values =
          value
          |> Enum.join(", ")

        render_array_type_value(type, values)
    end
  end

  def values_with_type(value, type) when is_tuple(value) do
    values =
      value
      |> tuple_to_array(type)
      |> Enum.join(", ")

    render_type_value(type, values)
  end

  def values_with_type(value, type) when type in ["address", "address payable"] do
    {:ok, address} = Explorer.Chain.Hash.Address.cast(value)
    render_type_value("address", to_string(address))
  end

  def values_with_type(value, "string"), do: render_type_value("string", value)

  def values_with_type(value, type), do: render_type_value(type, binary_to_utf_string(value))

  def values_only(value, type) when is_list(value) do
    with_type? = false

    cond do
      String.starts_with?(type, "tuple") ->
        values =
          value
          |> tuple_array_to_array(type, with_type?)
          |> Enum.join(", ")

        render_array_value(values)

      String.starts_with?(type, "address") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        render_array_value(values)

      String.starts_with?(type, "bytes") ->
        values =
          value
          |> Enum.map(&binary_to_utf_string(&1))
          |> Enum.join(", ")

        render_array_value(values)

      true ->
        values =
          value
          |> Enum.join(", ")

        render_array_value(values)
    end
  end

  def values_only(value, "address") do
    {:ok, address} = Explorer.Chain.Hash.Address.cast(value)
    to_string(address)
  end

  def values_only(value, "string") do
    value
  end

  def values_only(value, _type) do
    binary_to_utf_string(value)
  end

  defp tuple_array_to_array(value, type, with_type? \\ true) do
    type = type |> String.slice(0..-3)

    value
    |> Enum.map(fn item ->
      tuple_to_array(item, type, with_type?)
    end)
  end

  defp tuple_to_array(value, type, with_type? \\ true) do
    types_string =
      type
      |> String.slice(6..-2)
      |> String.split(",")

    {tuple_types, _} =
      types_string
      |> Enum.reduce({[], nil}, fn val, acc ->
        {arr, to_merge} = acc

        if to_merge do
          if count_string_symbols(val)["]"] > count_string_symbols(val)["["] do
            updated_arr = update_last_list_item(arr, val)
            {updated_arr, !to_merge}
          else
            updated_arr = update_last_list_item(arr, val)
            {updated_arr, to_merge}
          end
        else
          if count_string_symbols(val)["["] > count_string_symbols(val)["]"] do
            # credo:disable-for-next-line
            {arr ++ [val], !to_merge}
          else
            # credo:disable-for-next-line
            {arr ++ [val], to_merge}
          end
        end
      end)

    values_list =
      value
      |> Tuple.to_list()

    values_types_list = Enum.zip(tuple_types, values_list)

    values_types_list
    |> Enum.map(fn {type, value} ->
      if with_type? do
        values_with_type(value, type)
      else
        values_only(value, type)
      end
    end)
  end

  defp update_last_list_item(arr, new_val) do
    arr
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      if index == Enum.count(arr) - 1 do
        item <> "," <> new_val
      else
        item
      end
    end)
  end

  defp count_string_symbols(str) do
    str
    |> String.graphemes()
    |> Enum.reduce(%{"[" => 0, "]" => 0}, fn char, acc ->
      Map.update(acc, char, 1, &(&1 + 1))
    end)
  end

  defp binary_to_utf_string(item) do
    if is_binary(item), do: "0x" <> Base.encode16(item, case: :lower), else: item
  end

  defp render_type_value(type, value) do
    "<div style=\"padding-left: 20px\">(#{type}) : #{value}</div>"
  end

  defp render_array_type_value(type, values) do
    value_to_display = "[" <> values <> "]"

    render_type_value(type, value_to_display)
  end

  defp render_array_value(values) do
    value_to_display = "[" <> values <> "]"

    value_to_display
  end
end
