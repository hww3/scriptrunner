// our default timeout is 1 hour.
static int default_timeout = 3600;
static int cleaner_interval = 3600;

array session_storage = ({});

void create()
{
  start_session_cleaner();
}

void session_cleaner()
{

  do
  {
    werror("starting cleaner run.\n");
    foreach(session_storage;; .SessionStorage engine)
    {
      engine->clean_sessions(default_timeout);
    } 

    sleep(cleaner_interval);
  } 
  while(1);
}

void start_session_cleaner()
{
  // let's do this as a thread; it's easier that way.
    sleep(5);
    Thread.Thread cleaner = Thread.Thread(session_cleaner);
}

void set_default_timeout(int seconds)
{
  default_timeout = seconds;
}

void set_cleaner_interval(int seconds)
{
  cleaner_interval = seconds;
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

  foreach(session_storage;; .SessionStorage engine)
  {
    rv|=engine->expunge(sessionid);
  }

  return rv; 

}

.Session get_session(string sessionid)
{
  foreach(session_storage;; .SessionStorage engine)
  {
    .Session s = engine->get(sessionid);

    if(s) return s;
  }

  return .Session(sessionid);
}

void set_session(string sessionid, .Session session_data, int timeout)
{
  foreach(session_storage;; .SessionStorage engine)
  {
    engine->set(sessionid, session_data, timeout);
  }
}
