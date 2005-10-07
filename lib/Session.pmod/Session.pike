
string id = "";
static mapping attrs = ([]);
public mapping data = ([]);

string _sprintf(mixed ... args)
{
  return "Session(" + id + ", " + sprintf("%O", data) + ")";
}

void create(string sessionid)
{
  id = sessionid;
}

mixed get_attr(string attrname)
{
  return attrs[attrname];
}

void set_attr(string attrname, mixed value)
{
  attrs[attrname] = value;
}

