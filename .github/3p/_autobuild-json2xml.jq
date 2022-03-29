# jq helper for converting human-friendly autobuild.json into gory autobuild.xml


def _pad(level):
  "                                                                   "
  | .[0:(if (level|type == "number" and level > 0) then level*2 else 0 end)];

def _wrap(level; name; stuff):
  "<"+name+">"+(
    if (level < 0 or (stuff|length == 0)) then stuff else "\n"+(stuff)+"\n"+_pad(level) end
  )+"</"+name+">";

def _llsd(level; value):
  value as $value | 
  (
    if $value|type == "object" then
      _wrap(level-1; "map"; (
      [
        ( $value | to_entries[] )
        | (""+_pad(level)+"<key>"+.key+"</key>" + _llsd(level+1; .value) )
      ] | join("\n")
      ))
    elif $value|type == "array" then
      _wrap(level-1; "array"; [$value[]|_pad(level)+_llsd(level; .)]|join("\n"))
    elif $value|type == "string" then
      _wrap(-1; "string"; $value)
    else
      _wrap(-1; "UNKNOWN"; $value|tostring)
    end
  );

def llsd: 
  "<?xml version=\"1.0\" ?>\n"+
  "<llsd>\n" +
    _pad(1) + _llsd(2; .) + "\n" +
  "</llsd>";
  


