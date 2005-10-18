inherit .SessionStorage;

int writing_session = 0;

static string storage_dir;

void create()
{
}

void clean_sessions(int default_timeout)
{
  Filesystem.Traversion f = Filesystem.Traversion(storage_dir);

  foreach(f; string dir; string file)
  {
    Stdio.Stat s = f->stat();
    if(s && s->isreg && ((s->mtime+default_timeout) < time()))
    {
      werror("deleting stale session " + dir+file + "\n");
      rm(dir + file);
    }
    else if(!s && sizeof(get_dir(dir+file)) == 0)
    {
      // this is a really bad way to do this...
      if(!writing_session)
      {
        werror("deleting empty directory " + dir+file + "\n");
        Stdio.recursive_rm(dir+file);
      }
    }
  }

}

void set_storagedir(string directory)
{
  Stdio.Stat s;

  s = file_stat(directory);

  if(!s || !(s->isdir))
    throw(Error.Generic("Session Directory " + directory + " is non-existent or is not a directory.\n"));
  storage_dir = directory;
}

mixed get(string sessionid)
{
  string p;
  string sessionfile;
  mixed d;  
  .Session data;

  [p, sessionfile] = sessionfile_from_session(sessionid);

  if(!file_stat(sessionfile))
  {
    return 0;
  }

  p = Stdio.read_file(sessionfile);

  d = decode_value(p);

  if(d)
    data = .Session(sessionid);

  data->data = d;
  data->set_attr("FileSessionPath", sessionfile);

  return data;
}

int expunge(string sessionid)
{
 string sessionfile;
 string p;

 [p, sessionfile] = sessionfile_from_session(sessionid);

 if(file_stat(sessionfile))
 {
   return Stdio.recursive_rm(sessionfile);
 }
 else
 {
   return 0;
 }

}

void set(string sessionid, .Session data, int timeout)
{
 string sessionfile;

 writing_session = 1;
 if(data->get_attr("FileSessionPath"))
 {
   sessionfile = data->get_attr("FileSessionPath");
 }
 else
 {
   string p;

   [p, sessionfile] = sessionfile_from_session(sessionid);

   Stdio.mkdirhier(p);
 
   data->set_attr("FileSessionPath", sessionfile);
 }

 string d = encode_value(data->data); 

if(!sessionfile) 
{
  werror("Sessionfile not set! not saving session.\n");
  return;
}

   Stdio.write_file(sessionfile, d);
 writing_session = 0;
 return;
}

array sessionfile_from_session(string session)
{
   string sessionfile;
   array s = session/3.0;

   string p = Stdio.append_path(storage_dir, (s[0..sizeof(s)-2] * "/"));

   sessionfile = Stdio.append_path(p, s[-1] + ".dat");

   return ({p, sessionfile});
}
