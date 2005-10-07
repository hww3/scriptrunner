static storage_dir;

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

mixed get_session(string sessionid)
{
  return 0;
}

void set_session(string sessionid, mixed session_data, int timeout)
{

}
