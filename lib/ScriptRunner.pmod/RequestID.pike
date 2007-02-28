#define D(x) werror(sprintf("%O\n", x))

import Stdio;
import Protocols.HTTP;
import Protocols.HTTP.Server;

mapping (string:string) variables = ([ ]);
mapping (string:mixed) misc = ([ ]);

string query, not_query, rest_query;
static string data;

static object fast_cgi_request;

multiset   (string) prestate     = (< >);
multiset   (string) config       = (< >);
multiset   (string) supports     = (< >);

string remoteaddr, remotehost;

array  (string) client      = ({ });
array  (string) referer     = ({ });
multiset (string) pragma      = (< >);

mapping (string:string) cookies = ([ ]);

string prot;
string method;

void response_write_and_finish(mixed ... args)
{

        Thread.Mutex lock;
        Thread.MutexKey key;

        lock = Thread.Mutex();
        key = lock->lock();

        mixed e;

   e = catch{

        fast_cgi_request->real_write(@args);
        fast_cgi_request->finish();
};

if(e){
  werror(@args);
throw(e);
}
        key = 0;

}

static private void decode_query() {
  string v, a, b;	
  variables = ([]);
  if(!query)
    query = "";
  rest_query = "";
  foreach(query / "&", v)
    if(sscanf(v, "%s=%s", a, b) == 2)
    {
      a = http_decode_string(replace(a, "+", " "));
      b = http_decode_string(replace(b, "+", " "));
      
      if(variables[ a ])
	variables[ a ] +=  "\0" + b;
      else
	variables[ a ] = b;
    } else
      if(strlen( rest_query ))
	rest_query += "&" + http_decode_string( v );
      else
	rest_query = http_decode_string( v );
  rest_query=replace(rest_query, "+", "\000"); /* IDIOTIC STUPID STANDARD */
}

static private void decode_cookies()
{
  string c;
  foreach(misc->cookies/";", c)
  {
    string name, value;
    while(c[0]==' ') c=c[1..];
    if(sscanf(c, "%s=%s", name, value) == 2)
    {
      value=http_decode_string(value);
      name=http_decode_string(name);
      cookies[ name ]=value;
      if(name == "RoxenConfig" && strlen(value))
      {
	array tmpconfig = value/"," + ({ });
	string m;
	config = aggregate_multiset(@tmpconfig);
      }
    }
  }
}


private void decode_post()
{
  string a, b;
  if(!data) data="";
  int wanted_data=misc->len;
  int have_data=strlen(data);
  if(have_data < misc->len) // \r are included. 
  {
    werror("WWW.CGI parse: Short stdin read.\n");
    return 0;
  }
  data = data[..misc->len];
  switch(lower_case(((misc["content-type"]||"")/";")[0]-" "))
  {
   default: // Normal form data.
    string v;
    if(misc->len < 200000)
    {
      foreach(replace(data-"\n", "+", " ")/"&", v)
	if(sscanf(v, "%s=%s", a, b) == 2)
	{
	  a = http_decode_string( a );
	  b = http_decode_string( b );
	  
	  if(variables[ a ])
	    variables[ a ] +=  "\0" + b;
	  else
	    variables[ a ] = b;
	}
      break;
    }
   case "multipart/form-data":
    object messg = MIME.Message(data, misc);
    foreach(messg->body_parts||({}), object part) {
      if(part->disp_params->filename) {
      	string fname=part->disp_params->filename;
        if( part->headers["content-disposition"] ) {
          array fntmp=part->headers["content-disposition"]/";";
          if( sizeof(fntmp) >= 3 && search(fntmp[2],"=") != -1 ) {
            fname=((fntmp[2]/"=")[1]);
            fname=fname[1..(sizeof(fname)-2)];
          }
        }


	variables[part->disp_params->name]=part->getdata();
	variables[part->disp_params->name+".filename"]=fname;
	if(!misc->files)
	  misc->files = ({ fname });
	else
	  misc->files += ({ fname });
      } else {
	variables[part->disp_params->name]=part->getdata();
      }
    }
    break;
  }
}

string getenv(string key)
{
  if(!fast_cgi_request) 
    return 0;
  if(!fast_cgi_request->env[key])
    return 0;
  else return fast_cgi_request->env[key];
}

void create(object fcgir)
{
  string contents;

  fast_cgi_request = fcgir;

  contents = getenv("CONTENT_LENGTH");
  if(stringp(contents))
    misc->len = (int)(contents - " ");

  contents = getenv("CONTENT_TYPE");
  if(contents)
    misc["content-type"] = contents;

  contents = getenv("HTTP_HOST");
  if(stringp(contents) && strlen(contents)) 
    misc->host = contents;

  contents = getenv("HTTP_CONNECTION");
  if(stringp(contents) && strlen(contents)) 
    misc->connection = contents;

  contents = getenv("REMOTE_HOST");
  if(stringp(contents) && strlen(contents)) 
    remotehost = contents;

  remoteaddr = getenv("REMOTE_ADDR") ||"unknown";
  referer = (contents = getenv("HTTP_REFERER")) ? contents / " ": ({});
  
  contents = getenv("SUPPORTS");
  if(stringp(contents) && strlen(contents))
    supports = mkmultiset(contents / " ");

  contents = getenv("HTTP_USER_AGENT");
  if(stringp(contents))
    client = contents / " ";

  contents = getenv("HTTP_COOKIE"); 
  if(stringp(contents) && strlen(contents)) {
    misc->cookies = contents;
    decode_cookies();
  }

  contents = getenv("PRESTATES");
  if(stringp(contents) && strlen(contents))
    prestate = mkmultiset(Array.map(contents / " ",
				    lambda(string s) {
      return http_decode_string(replace(s, "+", " "));
    }));

  contents = getenv("HTTP_PRAGMA");
  if(stringp(contents) && strlen(contents))
    pragma |= aggregate_multiset(@replace(contents, " ", "")/ ",");

  not_query = getenv("REQUEST_URI");
  query = getenv("QUERY_STRING");
  method = getenv("REQUEST_METHOD") || "GET";
  prot = getenv("SERVER_PROTOCOL");

  foreach( ({"DOCUMENT_ROOT", "HOSTTYPE", "GATEWAY_INTERFACE", "PWD",
	       "SCRIPT_FILENAME", "SCRIPT_NAME", "REQUEST_URI",
	       "SERVER_SOFTWARE", "SERVER_PORT", "SERVER_NAME",
	       "SERVER_ADMIN", "REMOTE_PORT", "PATH_INFO",
	       "PATH_TRANSLATED" }), string s)
    if(contents = getenv(s)) {
      misc[lower_case(s)] = contents;
    }
  
  foreach(({ "HTTP_ACCEPT", "HTTP_ACCEPT_CHARSET", "HTTP_ACCEPT_LANGUAGE",
	       "HTTP_ACCEPT_ENCODING", }), string header)
    if(contents = getenv(header)) {
      header = replace(lower_case(header),
		       ({"http_", "_"}), ({"", "-"}));
      misc[header] = (contents-" ") / ",";
    }
  
  
  if(misc->len)
    data = fast_cgi_request->read(misc->len);
  
  decode_query(); // Decode the query string

  if(misc->len && method == "POST")
    decode_post(); // We have a post.. Decode it.
}
