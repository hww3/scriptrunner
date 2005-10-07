//! creates a redirect control mapping
mapping redirect(string to)
{
  return (["error": 302, "_headers": (["location": to])]);
}

//! creates an authorization control mapping
mapping auth_required(string realm, string message)
{
  if(!message)
    message = "<h1>Authorization Required</h1>";
  return (["error": 401, "data": message,  "_headers": (["WWW-Authenticate":"basic realm=\""+realm+"\""])]);
}

//! creates a configurable return type control mapping
mapping string_answer(string result, string mimetype)
{
  return (["data": result,  "_headers": (["content-type": mimetype])]);

}


//! creates a set-cookie control mapping
mapping set_cookie(string name, string value, int expiration_timestamp, mapping|void control)
{

  if(!control)
    control = (["data": "", "_headers" (["content-type": ]) ]);


  control->_headers["set-cookie"] = Protocols.HTTP.http_encode_cookie(name)+
		      "="+Protocols.HTTP.http_encode_cookie( value )+
		      "; expires="+Protocols.HTTP.http_date(timestamp)+"; path=/");

  return control;
}
