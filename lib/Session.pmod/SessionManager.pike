import ScriptRunner;

array session_storage = ({});

void create()
{

}

int expunge_session(string sessionid)
{
  int rv;

  foreach(session_storage;; SessionStorage engine)
  {
    rv|=engine->expunge(sessionid);
  }

  return rv; 

}

Session get_session(string sessionid)
{
  foreach(session_storage;; SessionStorage engine)
  {
    Session s = engine->get(sessionid);

    if(s) return s;
  }

  return Session(sessionid);
}

void set_session(string sessionid, Session session_data, int timeout)
{
  foreach(session_storage;; SessionStorage engine)
  {
    engine->set(sessionid, session_data, timeout);
  }
}
