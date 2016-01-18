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
    assert result["MultibyteStringKey"] == "あaいi熙☆ω"
  end

  test "Bplist file exist error" do
    assert_raise(Bplist.FileExistError, fn ->
      Bplist.load("NoSuchAsFile")
    end)
  end

  test "Bplist format error" do
    assert_raise(Bplist.FormatError, fn ->
      Bplist.load("test/check2.plist")
    end)
  end
end
