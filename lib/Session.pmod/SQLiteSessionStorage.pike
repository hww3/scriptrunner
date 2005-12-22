inherit .SessionStorage;

int writing_session = 0;

static string storage_dir;
static object sql;

void create()
{
}

void clean_sessions(int default_timeout)
{
  sql->query("DELETE FROM SESSIONS WHERE last_updated + " + default_timeout + " < CURRENT_TIMESTAMP");
}

void set_storagedir(string directory)
{
  mixed e;
  e = catch 
  {
    sql = Sql.Sql("SQLite://" + directory);
  };
  if(e) throw(Error.Generic("Unable to create session storage database " + directory + ".\n"));
  storage_dir = directory;

  if(!sizeof(sql->query("PRAGMA table_info(SESSIONS)")))
  {
    werror("creating sessions table...\n");
    sql->query("CREATE TABLE SESSIONS(sessionid varchar(15) PRIMARY KEY, data text, timeout timestamp)");
  }
}

mixed get(string sessionid)
{
  .Session data;
  string p;
  mixed d;

  array res = sql->query("SELECT * FROM SESSIONS WHERE sessionid='" + sessionid + "'");

  if(sizeof(res))
  {
    p = res[0]->data;
    d = decode_value(MIME.decode_base64(p));
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
  sql->query("DELETE FROM SESSIONS WHERE sessionid='" + sessionid + "'");
  return 1;
}

void set(string sessionid, .Session data, int timeout)
{
   string d = MIME.encode_base64(encode_value(data->data)); 

  sql->query("INSERT OR REPLACE INTO SESSIONS (sessionid, data, timeout) VALUES('" + 
    sessionid + "','" + d + "', CURRENT_TIMESTAMP)");

   return;
}
