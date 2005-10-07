import ScriptRunner;

array session_storage = ({});

void create()
{

}

string new_sessionid()
{
  object md5 = Crypto.MD5();
  md5->update(Crypto.randomness.reasonably_random()->read(24));
  md5->update(sprintf("%d", time(1)));

  return String.hex2string(md5->digest()[..8]);

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
