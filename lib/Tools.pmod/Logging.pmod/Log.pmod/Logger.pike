constant DEBUG = 1;
constant INFO = 2;
constant WARN = 4;
constant ERROR = 8;
constant CRITICAL = 16;

object stderr = Stdio.stderr;

// we start with a full log.
int loglevel = DEBUG|INFO|WARN|ERROR|CRITICAL;

mapping log_strs = ([
  DEBUG: "DEBUG", 
  INFO: "INFO",
  WARN: "WARN",
  ERROR: "ERROR",
  CRITICAL: "CRITICAL"
]);

static void do_msg(int level, string m, mixed|void ... extras)
{
  if(!(loglevel & level))
    return;

  if(extras && sizeof(extras))
  {
    m = sprintf(m, @extras);
  }

  stderr->write(log_strs[level] + ": " + m + "\n");
}

void exception(string msg, object|array exception)
{
  msg = msg + "\n%s";
  string e;

  if(objectp(exception))
    e = exception->describe();
  else e = describe_backtrace(e);
  stderr->write(sprintf("An exception occurred : " + msg + "\n", e));  
}

//!
void debug(string msg, mixed|void ... extras)
{
  do_msg(DEBUG, msg, @extras); 
}


//!
void info(string msg, mixed|void ... extras)
{
  do_msg(INFO, msg, @extras); 
}

//!
void warn(string msg, mixed|void ... extras)
{
  do_msg(WARN, msg, @extras); 
}

//!
void error(string msg, mixed|void ... extras)
{
  do_msg(ERROR, msg, @extras); 
}

//!
void critical(string msg, mixed|void ... extras)
{
  do_msg(CRITICAL, msg, @extras); 
}

//!
void set_level(int level)
{
  loglevel = level;
}
