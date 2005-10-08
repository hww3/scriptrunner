import ScriptRunner;

// our default timeout is 1 hour.
int default_timeout = 3600;

array session_storage = ({});

void create()
{
  call_out(start_session_cleaner, 5);
}

void session_cleaner()

void start_session_cleaner()
{
  // let's do this as a thread; it's easier that way.

  do
  {

    Thread.Thread cleaner = Thread.Thread(session_cleaner);
    werror("Session Cleaner ended, will restart in 10 seconds...\n");
    sleep(10);
  } 
  while(1);
}

void set_default_timeout(int seconds)
{
  default_timeout = seconds;
}

string new_sessionid()
{
  object md5 = Crypto.MD5();
  md5->update(Crypto.randomness.reasonably_random()->read(8));
  md5->update(sprintf("%d", time(1)));

  return String.string2hex(md5->digest()[..9]);

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
