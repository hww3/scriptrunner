inherit .SessionStorage;

mapping sessions = ([]);


void create()
{
}

void clean_sessions(int default_timeout)
{
  int t = time();

  foreach(sessions; string sid; array stor)
    if((stor[0] + default_timeout) < t)
      m_delete(sessions, sid);
}

mixed get(string sessionid)
{
  .Session data;
  mixed d;

  array sess = sessions[sessionid];

  if(sess)
  {
    d = sess[1];
  }
  else
  {
    return 0;
  }

  data = .Session(sessionid);
  data->data = d;

  return data;
}

int expunge(string sessionid)
{
  return m_delete(sessions, sessionid);
}

void set(string sessionid, .Session data, int timeout)
{
   sessions[sessionid] = ({ time(), data->data });

   return;
}
