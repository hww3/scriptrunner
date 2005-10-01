
mapping redirect(string to)
{
  return (["error": 302, "_headers": (["location": to])]);
}

mapping auth_required(string realm, string message)
{
  if(!message)
    message = "<h1>Authorization Required</h1>";
  return (["error": 401, "data": message,  "_headers": (["WWW-Authenticate":"basic realm=\""+realm+"\""])]);
}

mapping string_answer(string result, string mimetype)
{
  return (["data": result,  "_headers": (["content-type": mimetype])]);

}

