/ kdb-driver.q -- the local q that kdb.el starts loads this file.
/ The process holds one handle to a remote kdb server and evaluates the
/ text that Emacs sends. Results print here, at a wide console, so a remote
/ table renders in full. The last remote result stays in .kdb.last for local
/ work. kdb.el passes the target as environment variables.
/ Note: a line holding only "/" opens a block comment in q. Keep text after
/ every comment marker in this file.

system "c 2000 2000";

.kdb.target:`host`port`user`name!getenv each `KDB_HOST`KDB_PORT`KDB_USER`KDB_NAME;

/ Open the handle. Call again after a dropped connection.
.kdb.connect:{[]
  .kdb.h:hopen `$":",":" sv .kdb.target[`host`port`user],enlist "";
  -1 "kdb: connected to ",.kdb.target[`name]," (",.kdb.target[`host],":",.kdb.target[`port],")";
  .kdb.h};

/ Split TEXT into statements, the same rule as run.sh: a blank line or a
/ /-comment line separates statements, and consecutive lines join.
.kdb.split:{[text]
  lines:"\n" vs text;
  sep:{$[0=count t:x where not x=" ";1b;"/"=first t]} each lines;
  idx:where not sep;
  $[count idx;{" " sv x} each lines (0,where 1<@[deltas idx;0;:;1]) cut idx;()]};

/ Evaluate one statement remotely. Print the result, or the error, and
/ keep a successful result in .kdb.last.
.kdb.exec:{[stmt]
  res:@[{(1b;.kdb.h x)};stmt;{(0b;x)}];
  $[first res;[.kdb.last:last res;show .kdb.last];-2 "ERR: ",last res];};

.kdb.run:{[text] .kdb.exec each .kdb.split text;};

.kdb.connect[];
