function tpc_run_mode_entry(codeDir,entry)
old=pwd;cd(codeDir);cleanup=onCleanup(@()cd(old));
feval(entry);
end
