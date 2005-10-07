import ScriptRunner;
inherit SessionStorage;

static string storage_dir;

void create()
{
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
  Session data;

  [p, sessionfile] = sessionfile_from_session(sessionid);

  if(!file_stat(sessionfile))
  {
    return 0;
  }

  p = Stdio.read_file(sessionfile);

  d = decode_value(p);

  if(d)
    data = Session(sessionid);

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

void set(string sessionid, Session data, int timeout)
{
 string sessionfile;

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
