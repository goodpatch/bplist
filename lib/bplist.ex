defmodule Bplist do

  import Bitwise
  import Floki

  defstruct fp: <<>>, object_ref_size: 1, offsets: [], body: <<>>

  defmodule FileExistError do
    defexception message: "File does not exist"
  end

  defmodule HeaderError do
    defexception message: "This file is not binary-plist file"
  end

  defmodule FormatError do
    defexception message: "Format error"
  end

  defmodule IntegerError do
    defexception message: "Integer greater than 8 bytes"
  end

  defmodule UnknownNullType do
    defexception message: "Unknown null type"
  end

  defmodule RealError do
    defexception message: "Real greater than 8 bytes"
  end

  def load(file) do
    body = case File.read(file) do
      {:ok, body} -> body
      {:error, _} -> raise FileExistError
    end

    load_from_data(body)
  end

  def load_from_data(body) do
    << header :: bitstring-size(64), data :: binary >> = body

    if header == "bplist00" do
      load_binary(header, data, body)
    else
      load_xml(body)
    end
  end

  defp load_xml(body) do
    xml = Floki.parse(body)
    if is_binary(xml) == true do
      raise FormatError
    end
    parsed = Enum.at(Floki.parse(body), 1)
    define_line = elem(parsed, 0)
    plist_version = Enum.at(elem(parsed, 1), 0)
    if define_line != "plist" || plist_version != {"version", "1.0"} do
      raise FormatError
    else
      content = Enum.at(elem(parsed, 2), 0)
      Enum.into(xmlToMap(elem(content, 2), []), %{})
    end
  end

  defp load_binary(header, data, body) do
    own = %Bplist{}

    cont_size = byte_size(data) - 32
    << m :: binary-size(cont_size), buffer :: binary >> = data
    << 0, 0, 0, 0, 0, 0, offset_size :: unsigned-size(8), object_ref_size :: unsigned-size(8), 0, 0, 0, 0, number_of_objects :: unsigned-integer-size(32), 0, 0, 0, 0, top_object :: unsigned-integer-size(32), 0, 0, 0, 0, table_offset :: unsigned-integer-size(32) >> = buffer
    << _ :: binary-size(table_offset), offset_table_binary :: binary >> = body
    coded_offset_table_size = number_of_objects * offset_size
    <<coded_offset_table :: binary-size(coded_offset_table_size), _ :: binary>> = offset_table_binary

    if byte_size(coded_offset_table) != (number_of_objects * offset_size) do
      raise FormatError
    end

    format_unpackers = {
      fn data, out -> "" end,
      fn data, out -> star_unpack("B", data, out) end,
      fn data, out -> star_unpack("H", data, out) end,
      fn data, out -> nil end,
      fn data, out -> star_unpack("L", data, out) end
    }
    offsets = elem(format_unpackers, offset_size).(coded_offset_table, [])

    own = %{own | offsets: offsets}
    own = %{own | fp: m}
    own = %{own | object_ref_size: object_ref_size}
    own = %{own | body: body}

    elem(read_binary_object_at(own, top_object), 1)
  end

  defp read_binary_object_at(own, pos) do
    position = Enum.at(own.offsets, pos)
    << _ :: binary-size(position), rest :: binary >> = own.body
    own = %{own | fp: rest}
    read_binary_object(own)
  end

  defp read_binary_object(own) do
    << buff :: binary-size(1), rest :: binary >> = own.fp
    own = %{own | fp: rest}

    object_length = star_unpack("B", buff, [])
    object_length = hd(object_length) &&& 0xf

    buff = Hexate.encode(buff)
    object_type = String.first(buff)

    if object_type != "0" and object_length == 15 do
      {own, object_length} = read_binary_object(own)
    end

    case object_type do
      "0" -> read_binary_null_type(own, object_length)
      "1" -> read_binary_int(own, object_length)
      "2" -> read_binary_real(own, object_length)
      "3" -> read_binary_date(own, object_length)
      "4" -> read_binary_data(own, object_length)
      "5" -> read_binary_string(own, object_length)
      "6" -> read_binary_unicode_string(own, object_length)
      "a" -> read_binary_array(own, object_length)
      "d" -> read_binary_dict(own, object_length)
    end
  end

  defp read_binary_null_type(own, len) do
    case len do
      0 -> {own, 0}
      8 -> {own, false}
      9 -> {own, true}
      15 -> {own, 15}
      _ -> raise UnknownNullType
    end
  end

  defp read_binary_int(own, len) when len <= 3 do
    nbytes = 1 <<< len
    << buff :: binary-size(nbytes), rest :: binary >> = own.fp
    own = %{own | fp: rest}

    case len do
      0 -> << val :: unsigned-size(8) >> = buff
      1 -> << val :: unsigned-integer-size(16) >> = buff
      2 -> << val :: unsigned-integer-size(32) >> = buff
      3 ->
        << hiword :: unsigned-integer-size(32), loword :: unsigned-integer-size(32) >> = buff
        if hiword &&& 0x80000000 != 0 do
          val = -(:math.pow(2, 63) - ((hiword &&& 0x7fffffff) <<< 32 ||| loword))
        else
          val = hiword <<< 32 ||| loword
        end
    end
    {own, val}
  end

  defp read_binary_int(own, len) when len > 3 do
    raise IntegerError
  end

  defp read_binary_real(own, len) when len <= 3 do
    nbytes = 1 <<< len
    << buff :: binary-size(nbytes), rest :: binary >> = own.fp
    own = %{own | fp: rest}
    << val :: float >> = buff
    {own, val}
  end

  defp read_binary_real(own, len) when len > 3 do
    raise RealError
  end

  # Return Mach Absolute Time
  defp read_binary_date(own, len) when len <= 3 do
    nbytes = 1 <<< len
    << buff :: binary-size(nbytes), rest :: binary >> = own.fp
    own = %{own | fp: rest}
    << val :: float >> = buff
    {own, val}
  end

  defp read_binary_string(own, len) when len > 0 do
    << buff :: binary-size(len), rest :: binary >> = own.fp
    own = %{own | fp: rest}
    {own, buff}
  end

  defp read_binary_string(own, len) when len > 0 do
    {own, ""}
  end

  defp read_binary_data(own, len) when len > 0 do
    << buff :: binary-size(len), rest :: binary >> = own.fp
    own = %{own | fp: rest}
    {own, Base.encode64(buff)}
  end

  defp read_binary_unicode_string(own, len) do
    size = len * 2
    << buff :: binary-size(size), rest :: binary >> = own.fp
    out = encode_unicode_string(buff, "")
    own = %{own | fp: rest}
    {own, out}
  end

  defp read_binary_array(own, len) when len != 0 do
    size = len * own.object_ref_size
    << buff :: binary-size(size), rest :: binary >> = own.fp
    own = %{own | fp: rest}

    case own.object_ref_size do
      1 -> objects = star_unpack("B", buff, [])
      _ -> objects = star_unpack("H", buff, [])
    end
    max = len - 1
    res = Enum.map(0..max, fn i ->
      elem(read_binary_object_at(own, Enum.at(objects, i)), 1)
    end)
    {own, res}
  end

  defp read_binary_array(own, len) when len == 0 do
    {own, []}
  end

  defp read_binary_dict(own, len) when len != 0 do
    res = %{}

    size = len * own.object_ref_size
    << buff :: binary-size(size), rest :: binary >> = own.fp
    own = %{own | fp: rest}

    case own.object_ref_size do
      1 -> keys = star_unpack("B", buff, [])
      _ -> keys = star_unpack("H", buff, [])
    end

    << buff :: binary-size(size), rest :: binary >> = own.fp
    own = %{own | fp: rest}

    case own.object_ref_size do
      1 -> objects = star_unpack("B", buff, [])
      _ -> objects = star_unpack("H", buff, [])
    end

    max = len - 1
    res = for i <- 0..max do
      key = read_binary_object_at(own, Enum.at(keys, i))
      obj = read_binary_object_at(own, Enum.at(objects, i))
      Dict.put(res, elem(key, 1), elem(obj, 1))
    end
    {own, set_dictionary(res)}
  end

  defp read_binary_dict(own, len) when len == 0 do
    {own, %{}}
  end

  defp set_dictionary(result) do
    for x <- result, into: %{} do
      {hd(Dict.keys(x)), Dict.get(x, hd(Dict.keys(x)))}
    end
  end

  defp encode_unicode_string(binary, out) when byte_size(binary) == 0 do
    out
  end

  defp encode_unicode_string(binary, out) do
    << multi_byte :: binary-size(2), rest :: binary >> = binary
    << utf16_string :: utf16 >> = multi_byte
    out = out <> << utf16_string :: utf8 >>
    encode_unicode_string(rest, out)
  end

  defp unpack_helper(format, data) do
    case format do
      "B" ->
        << tmp_binary :: unsigned-size(8), rest :: binary >> = data
      "H" ->
        << tmp_binary :: unsigned-integer-size(16), rest :: binary >> = data
      "L" ->
        << tmp_binary :: unsigned-integer-size(32), rest :: binary >> = data
    end
    {rest, tmp_binary}
  end

  defp star_unpack(format, data, out) when byte_size(data) == 0 do
    out
  end

  defp star_unpack(format, data, out) do
    d = unpack_helper(format, data)
    star_unpack(format, elem(d, 0), out ++ [elem(d, 1)])
  end

  defp array_value(arr, result) when length(arr) != 0 do
    [first | rest] = arr
    value = elem(xmlToMap([first], []), 0)
    array_value(rest, result ++ [value])
  end

  defp array_value(arr, result) when length(arr) == 0 do
    result
  end

  defp xmlToMap(content, result) when length(content) != 0 do
    [node | rest] = content
    case elem(node, 0) do
      "key" ->
        key = getNodeValue(node)
        {value, rest} = xmlToMap(rest, result)
        xmlToMap(rest, result ++ [{key, value}])
      "dict" ->
        arr = elem(node, 2)
        result = xmlToMap(arr, [])
        {Enum.into(result, %{}), rest}
      "array" ->
        arr = elem(node, 2)
        result = array_value(arr, [])
        {result, rest}
      "true" ->
        {true, rest}
      "false" ->
        {false, rest}
      "integer" ->
        {elem(Integer.parse(getNodeValue(node)), 0), rest}
      "date" ->
        {getNodeValue(node), rest}
      "string" ->
        {getNodeValue(node), rest}
    end
  end

  defp xmlToMap(content, result) when length(content) == 0 do
    result
  end

  defp getNodeValue(node) do
    Enum.at(elem(node, 2), 0)
  end
end
