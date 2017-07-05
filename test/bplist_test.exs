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

  test "XML" do
    result = Bplist.load("test/check3.plist")
    assert result[nil] == "Hoge"
    assert result["StringKey"] == "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    assert result["IntegerKey"] == 10
    assert result["BinaryKey"] == "\n\tAQI=\n\t"
    assert result["DateKey"] == "2014-12-31T15:00:00Z"
    assert result["BooleanTrueKey"] == true
    assert result["BooleanFalseKey"] == false
    assert result["ArrayKey"] == [true, "Item1", 123456789]
    assert result["DictionaryKey"] == %{"DictKey1" => "DictString", "DictKey2" => false}
    assert result["MultibyteStringKey"] == "あaいi熙☆ω"
    assert result["EmptyString"] == nil
    assert result["EmptyDictionaryKey"] == %{nil => "Hoge", "DictEmptyKey" => nil}
  end

  test "Empty string" do
    result = Bplist.load("test/check4.plist")
    assert result[""] == "Hoge"
    assert result["EmptyString"] == ""
    assert result["EmptyDictionaryKey"][""] == "Hoge"
    assert result["EmptyDictionaryKey"]["DictEmptyKey"] == ""
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
