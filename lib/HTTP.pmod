import ScriptRunner;

//! creates a redirect control mapping
mapping redirect(string to, RequestID id)
{
  return (["error": 302, "_headers": (["location": to])]);
}

//! creates an authorization control mapping
mapping auth_required(string realm, string message, RequestID id)
{
  if(!message)
    message = "<h1>Authorization Required</h1>";
  return (["error": 401, "data": message,  "_headers": (["WWW-Authenticate":"basic realm=\""+realm+"\""])]);
}

//! creates a configurable return type control mapping
mapping string_answer(string result, string mimetype, RequestID id)
{
  return (["data": result,  "_headers": (["content-type": mimetype])]);

}


//! creates a set-cookie control mapping
mapping set_cookie(string name, string value, int expiration_timestamp, RequestID id)
{

  mapping control = (["_headers": ([]) ]) ;

  control->_headers["set-cookie"] = Protocols.HTTP.http_encode_cookie(name)+
		      "="+Protocols.HTTP.http_encode_cookie( value )+
		      "; expires="+Protocols.HTTP.Server.http_date(expiration_timestamp)+"; path=/";

  return control;
}

string encode(string s)
{
   string s2 = "";
   
   foreach((array)s;;int c)
   {
      s2+="&#" + c + ";";
   }
   return s2;
}