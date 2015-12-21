defmodule BplistTest do
  use ExUnit.Case
  doctest Bplist

  test "Bplist Load Test" do
    result = Bplist.load("test/check.plist")
    assert result["StringKey"] == "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    assert result["IntegerKey"] == 10
    assert result["BinaryKey"] == "AQI="
    assert result["DateKey"] == 4.417308e8
    assert result["BooleanTrueKey"] == true
    assert result["BooleanFalseKey"] == false
    assert result["ArrayKey"] == [true, "Item1", 123456789]
    assert result["DictionaryKey"] == %{"DictKey1" => "DictString", "DictKey2" => false}
  end

  test "Bplist Error Test" do
    assert_raise(MatchError, fn ->
      Bplist.load("NoSuchAsFile")
    end)
    assert_raise(Bplist.HeaderError, fn ->
      Bplist.load("test/check2.plist")
    end)
  end
end
