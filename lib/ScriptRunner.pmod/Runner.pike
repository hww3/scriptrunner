#!/usr/local/bin/pike -M/Users/hww3/Fins/lib

import Tools.Logging;

constant my_version = "0.3";
//#define RUN_THREADED

string session_storagetype = "ram";
string session_storagedir = ""; // not required for ram storage.

//string session_storagetype = "sqlite";
//string session_storagedir = "/tmp/scriptrunner_storage.db";

//string session_storagetype = "file";
//string session_storagedir = "/tmp/scriptrunner_storage";

string logfile_path = "/tmp/scriptrunner.log";
string session_cookie_name = "PSESSIONID";
int session_timeout = 3600;
Stdio.File f;
Stdio.File logfile;
int shutdown = 0;
int requests = 0;
int my_port;
mapping compiled_scripts = ([]);
Session.SessionManager session_manager;

string mode = "";

void print_help(string v)
{
        werror("Help:  %s [-p portnum|--port=portnum] [-c configname|--config=configname] [-a appdir|--appdir=appdir]\n", v);
}

int main(int argc, array(string) argv)
{
  int sock;

  foreach(Getopt.find_all_options(argv,aggregate(
    ({"port",Getopt.HAS_ARG,({"-p", "--port"}) }),
    ({"appdir",Getopt.HAS_ARG,({"-a", "--appdir"}) }),
    ({"config",Getopt.HAS_ARG,({"-c", "--config"}) }),
    ({"help",Getopt.NO_ARG,({"--help"}) }),
    )),array opt)
    {
      switch(opt[0])
      {
              case "help":
                print_help(argv[0]);
                exit(1);
                break;

              case "port":
                my_port = (int)opt[1];
                break;

      }
    }
  Log.info("ScriptRunner starting in %s mode.", mode);
  Log.info("Starting Session Manager...");
  session_startup();

  add_constant("RequestID", ScriptRunner.RequestID);
  add_constant("Session", Session.Session);
  add_constant("session_manager", session_manager);


  return start_listener(my_port);

}

int start_listener(int port);

void session_startup()
{
  Session.SessionStorage s;

  session_manager = Session.SessionManager();
  if(session_storagetype == "file")
  {
    s = Session.FileSessionStorage();
    s->set_storagedir(session_storagedir);
  }
  else if(session_storagetype == "ram")
  {
    s = Session.RAMSessionStorage();
  }
  session_manager->set_default_timeout(session_timeout);
  session_manager->set_cleaner_interval(session_timeout);
  session_manager->session_storage = ({s});

}

void handle_request(object request_id, int id)
{
  mixed e;
  String.Buffer response = String.Buffer();

                e = catch {
                // do we have a script file passed?
                if(request_id->misc && ((request_id->misc->path_info && 
                       sizeof(request_id->misc->path_info))||( 
request_id->misc->script_filename && sizeof(request_id->misc->script_filename)) ))
                {
                   object|string s;
                   string sp = (request_id->misc->path_translated ||
                                    request_id->misc->script_filename);
                  s = get_script(sp, request_id);
                  if(stringp(s))
                  {
                    request_id->response_write_and_finish("Content-type: text/html\r\n\r\n"
                                   "<h1>Compile Error</h1><pre>" + s + "</pre>");
                    return;
                  }
		  log("running script %s\n",(request_id->misc->request_uri||""));

                  // do we need to load up a session?
                  if(s["__participates_in_session"] && s["__participates_in_session"] != 0)
                  {
		    // Do we have either the session cookie or the PSESSIONID var?
                    if(request_id->cookies && request_id->cookies[session_cookie_name] 
                      || request_id->variables[session_cookie_name] )
                    {
                      string ssid=request_id->cookies[session_cookie_name]||request_id->variables[session_cookie_name];
                      Session.Session sess = session_manager->get_session(ssid);
                      request_id->misc->_session = sess;
                      request_id->misc->session_id = sess->id;
                      request_id->misc->session_variables = sess->data;
                    }
                    // if we don't have the session identifier set, we should set one.
                    else 
                    {
		      string ssid=session_manager->new_sessionid();
                      mapping r = HTTP.set_cookie(session_cookie_name, 
                                                  ssid, time() + session_timeout, request_id);
                      r->status = 302;
                      
		      string req=combine_path(request_id->misc->script_name,request_id->misc->path_info);
		      req += "?PSESSIONID="+ssid;
		      if( sizeof(request_id->query) )  {
		      	req += "&"+request_id->query;
		      }
                      r->_headers["location"] = req;

		      log( "Created new session sid='%s' host='%s'\n",ssid,request_id->remoteaddr);
                      request_id->response_write_and_finish( retval_to_response(r));
                      return;
                    }
                  }

                  // the moment of truth!
                  mixed retval;
                  retval = s->parse(request_id);

                  // should we be doing this unconditionally?
                  if(s["__participates_in_session"] && s["__participates_in_session"] != 0)
                  {
                    if(request_id->misc->_session)
                    {
                      // we need to set this explicitly, in case the link was broken.
                      request_id->misc->_session->data = request_id->misc->session_variables;
                      session_manager->set_session(request_id->misc->_session->id, request_id->misc->_session, 
                                                   session_timeout);
                    }
                  }

                  response += retval_to_response(retval);       
                }
                // no, then just print info.
                else
                {
  		  response+="Content-type: text/html\r\n\r\n";
                  response+="<h1>Pike ScriptRunner v" + my_version + "</h1>\n";
		  response+=sprintf("Hello world, this is page (%O) request #%d generated by thread %d\n", request_id->not_query, requests, id);
                  response+="<p><b>Pike Info:</b>\n";
                  response+=sprintf("<pre>\n%s\n</pre>\n", version());
                  response+="<b>Request Info:</b>\n";
		  response+=sprintf("<pre>\nID: %O\n</pre>", 
                    mkmapping(indices(request_id), values(request_id)));
                }

              };

              if(e)
              {
                if(objectp(e))
                  log("got an error: %s\n", e->describe());
                else
                  log("got an error: %O\n", e);
                response+="Content-type: text/html\r\n\r\n";
                response+=sprintf("<h1>\n%s\n</h1>", describe_error(e)); 
                response+=sprintf("<pre>\n%s\n</pre>", describe_backtrace(e)); 
              }

              request_id->response_write_and_finish(response->get());

              log("request finished\n");
                

}


//!  given a path to a script, this function will return the instantiated script
//!   
//!  @returns
//!   the script object, or a string describing the failure, if unsuccessful. 
//!
string|object get_script(string path, object id)
{
  string code;
  program p;
  Stdio.Stat stat;

// do we need this after all?
//  path = combine_path(path);

  stat = file_stat(path);

  if(!stat)
    error("Script does not exist.\n");

  if((compiled_scripts[path] && compiled_scripts[path][0] == stat->mtime)
         && !id->pragma["no-cache"])
    return compiled_scripts[path][1];

  log("compiling file %s\n", path);

  code = Stdio.read_file(path);

  if(!code)
    error("Script is an empty file.\n");

  if(path[sizeof(path)-4..] == ".psp")
  {
     log("  compiling as a psp\n");
     Web.PikeServerPages.PSPCompiler compiler = Web.PikeServerPages.PSPCompiler();
     compiler->document_root = id->misc->document_root || "/tmp";
     code = compiler->parse_psp(code, path);
  }

  object er = ErrorContainer();

  master()->set_inhibit_compile_errors(er);
  catch(p = compile_string(code));
  master()->set_inhibit_compile_errors(0);
  
  if(!p) // an error must have occurred...
  {
    log("%s", er->get());
    return er->get();
  }

  array ent = ({ stat->mtime, p() });

  compiled_scripts[path] = ent;

  return ent[1];
}

void log(string t, mixed ... args)
{
  if(!logfile) return;

  if(args)
    t = sprintf(t, @args);
  logfile->write(sprintf("[%s] %s", (ctime(time())- "\n"), t));
}

//!
class LowErrorContainer
{
  string d;
  string errors="", warnings="";
  string get()
  {
    return errors;
  }

  //!
  string get_warnings()
  {
    return warnings;
  }

  //!
  void print_warnings(string prefix) {
    if(warnings && strlen(warnings))
      log(prefix+"\n"+warnings);
  }

  //!
  void got_error(string file, int line, string err, int|void is_warning)
  {
    if (file[..sizeof(d)-1] == d) {
      file = file[sizeof(d)..];
    }
    if( is_warning)
      warnings+= sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
    else
      errors += sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
  }

  //!
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
 
  //!
  void compile_warning(string file, int line, string err)
  {  
    got_error(file, line, "Warning: " + err, 1);
  }
      
  //!
  void create()
  {  
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}
    
//! @appears ErrorContainer
class ErrorContainer
{
  inherit LowErrorContainer;

  //!
  void compile_error(string file, int line, string err)
  {
//    if( sizeof(compile_error_handlers) )   
//      compile_error_handlers->compile_error( file,line, err );
//    else
      ::compile_error(file,line,err);
  }
    
  //!
  void compile_warning(string file, int line, string err)
  {   
//    if( sizeof(compile_error_handlers) )
//      compile_error_handlers->compile_warning( file,line, err );
//    else
      ::compile_warning(file,line,err);
  }
}

string retval_to_response(mixed retval)
{
   string response="";

              if(!stringp(retval))
                     {
                        if(mappingp(retval))
                        {

                          if(!retval->_headers)
                            retval->_headers = ([]);
                          if(!retval->error)
                            retval->error = 200;
                          if(!retval->type)
                            retval->type = "text/html";

                          response+=sprintf("Status: %d\r\n", retval->error);

                          if(retval->_headers["content-type"]) ; // DO NOTHING!
                          else 
                            response+=sprintf("Content-type: %s\r\n", retval->type);

                          foreach(retval->_headers; string hname; string hvalue)
                            response+=sprintf("%s: %s\r\n", String.capitalize(hname), hvalue);

                          response+="\r\n";

                          // TODO: don't think we can get it all in one call.
                          if(objectp(retval->data))
                            response+=retval->data->read();
                          else if(retval->data)
                            response+=retval->data;

                        } 
                        else error("Invalid return value from parse().\n");
                     }
                     else
                     {
                        response+="Content-type: text/html\r\n\r\n";
                        response+=retval;
                     }

  return response;
}
