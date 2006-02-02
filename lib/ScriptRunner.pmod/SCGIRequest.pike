inherit ScriptRunner.RequestID;

void response_write_and_finish(mixed ... args)
{
        Thread.Mutex lock;
        Thread.MutexKey key;

        lock = Thread.Mutex();
        key = lock->lock();

        mixed e;

   e = catch{

        fast_cgi_request->write(@args);
        fast_cgi_request->finish();
};

if(e){
throw(e);
}
        key = 0;

}

string getenv(string key)
{
  if(!fast_cgi_request) 
    return 0;
  if(!fast_cgi_request->env[key])
    return 0;
  else return fast_cgi_request->env[key];
}

static void create(Stdio.File myfd)
{
  object scgir = SCGIConn(myfd);
  
  ::create(scgir);
}


//! @todo
//!   we should be doing nonblocking io here.
class SCGIConn
{
  mapping env = ([]);
  Stdio.File fd;

  function read;
  function finish;
  function write;

  static void create(Stdio.File myfd)
  {
    fd = myfd;
    read = myfd->read;
    finish = myfd->close;
    write = myfd->write;
    parse_request();
  }

  void parse_request()
  {
    string headerblock = read_netstring(fd);

    if(!headerblock) throw(Error.Generic("error reading headers.\n"));
    env = (mapping)((headerblock/"\000")/2);
    if(!env["CONTENT_LENGTH"])
    {
      throw(Error.Generic("No CONTENT_LENGTH provided.\n"));
    }

    // werror("ENV: %O\n\n", env);
  }

  string read_netstring(object fd)
  {
    int len;
    int pos;

    string buf;
    fd->set_blocking();
    buf = fd->read(7); // 6 bytes should be enough to get us started.

    pos = search(buf, ":");

    if(pos == -1 && sizeof(buf) > 7)
    {
      throw(Error.Generic("netstring format error... no : found in first 7 characters.\n"));
    }
    // TODO: we should be looping if we get less than 7 characters.    

    else
    {
      len = (int)buf[..(pos-1)];
      buf = buf[pos+1..];
    }

    buf += fd->read((len - sizeof(buf))+1);
    if(buf[-1] != ',')
    {
      throw(Error.Generic("netstring format error; expected trailing ,.\n"));
    }


    return buf[..(len-1) ];

  }
}

