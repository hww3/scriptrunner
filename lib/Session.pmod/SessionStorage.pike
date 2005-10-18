
void create()
{

}

void clean_sessions(int default_timeout);
.Session get(string sessionid);
int expunge(string sessionid);
void set(string sessionid, .Session data, int timeout);

