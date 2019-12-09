/++ dub.json:
{
    "name": "qshow",
    "dependencies": {
        "colorize": "~>1.0.5"
    }
}
+/
import std;
import colorize;


auto removeArrayJobParent(R)(R r)
{
    return r.filter!(a => !a["key"].str.endsWith("[]"));
}


auto removeTerminatedJob(R)(R r)
{
    return r.filter!(a => a["job_state"].str != "X");
}


auto getUserJobs(R)(R r, string user)
{
    return r.filter!(a => a["Variable_List"]["PBS_O_LOGNAME"].str == user);
}


auto memBytes(string s)
{
    return s.replace("gb", "000000000").replace("mb", "000000").replace("kb", "000").to!long;
}


auto toGB(string s)
{
    return format!"%6.1fGB"(memBytes(s) / 1E9);
}


auto jobSort(R)(R r)
{
    static
    string jobIden(JSONValue job)
    {
        auto key = job["key"].str;
        auto jobname = key.findSplitBefore("[")[0];
        size_t idx = 0;
        if(key.canFind("[")) {
            idx = key.findSplitAfter("[")[1][0 .. $-1].to!int;
        }

        return format("%s--%02d", jobname, idx);
    }

    return r.array.sort!((a, b) => jobIden(a) < jobIden(b) ).array();
}


void main()
{
    auto pbsnodesResult = execute(["pbsnodes", "-aSj", "-F", "json"]);
    enforce(pbsnodesResult.status == 0, "`pbsnodes -aSj` is failed.");

    auto nodeList = pbsnodesResult.output.parseJSON()["nodes"].object.byKeyValue.map!((a){
        a.value["key"] = a.key;
        return a.value;
    }).array().sort!q{a["key"].str < b["key"].str};

    auto qstatResult = execute(["qstat", "-ft", "-F", "json"]);
    enforce(qstatResult.status == 0, "`qstat -ft -F json` is failed.");

    auto jobList = qstatResult.output.parseJSON()["Jobs"].object.byKeyValue.map!((a){
        a.value["key"] = a.key.replace(".xregistry0", "");
        return a.value;
    }).removeArrayJobParent.array();


    // Show nodes
    {
        writeln("vnode\tnjobs\tncpus f/t\tmem f/t\t\tgpu\tusers");
        writeln("-----\t-----\t---------\t-----------\t---\t-----");
        foreach(node; nodeList) {
            auto name = node["key"].str;
            auto jobids = node["jobs"].array.map!(a => a.str.replace(".xregistry0", "")).array().sort.uniq.array();
            auto njob = jobids.length;
            auto mem = node["mem f/t"].str;
            auto ncpus = node["ncpus f/t"].str;
            auto ngpus = node["ngpus f/t"].str;

            long[string] userCPUs;
            foreach(jobid; jobids) {
                auto r = jobList.find!(a => a["key"].str == jobid);
                if(r.empty) continue;

                auto jobinfo = r.front;
                auto user = r.front["Variable_List"]["PBS_O_LOGNAME"].str;

                if(user !in userCPUs)
                    userCPUs[user] = 0;

                if(jobinfo["Resource_List"]["nodect"].integer == 1 && jobinfo["Resource_List"]["nodes"].integer == 1) {
                    userCPUs[user] += jobinfo["Resource_List"]["ncpus"].integer;
                } else {
                    // MPIなどで複数ノードにまたがるジョブの処理
                    // exec_vnodeには (xsnd03:mem=1234kb:ncpus=1)+(xsnd04:mem=1234kb:ncpus=1)+(xsnd07:mem=1234kb:ncpus=1)+(xsnd08:mem=1234kb:ncpus=1)
                    // のような値が入っているのでこれを集計する
                    auto resourceList = jobinfo["exec_vnode"].str.split("+").map!"a[1..$-1]".find!(a => a.startsWith(name));
                    if(resourceList.empty)
                        continue;

                    auto resources = resourceList.front.split(":");
                    auto ncpus_f = resources.find!(a => a.startsWith("ncpus="));
                    if(ncpus_f.empty){
                        userCPUs[user] += 1;
                        continue;
                    }

                    userCPUs[user] += ncpus_f.front[6 .. $].to!int;  // remove "ncpus=" and convert to int
                }
            }

            auto usercpus = userCPUs.byKeyValue.map!q{format!"%7s*%2s"(a.key, a.value)}.array();

            auto fmt = "%6s\t%5s\t%9s\t%11s\t%3s\t%-(%s, %)";
            if(ncpus.startsWith("0/") || mem.startsWith("0gb")) {
                fmt = fmt.color(fg.red);
            }
            cwritefln(fmt, name, njob, ncpus, mem, ngpus, usercpus);
        }
    }

    writeln();


    // List of all users
    auto userList = jobList.map!q{a["Variable_List"]["PBS_O_LOGNAME"].str}.array().sort().uniq.array();

    writeln("Username\ttJob\ttCPU\ttMem\t\trJob\trCPU\trMem");
    writeln("----------\t----\t----\t--------\t----\t----\t--------");
    foreach(user; userList) {
        auto totJobs = jobList.removeTerminatedJob().getUserJobs(user).array();
        auto runJobs = totJobs.filter!q{a["job_state"].str == "R"}.array();

        Tuple!(size_t, long, string) aggregate(JSONValue[] list) {
            size_t len = list.length;
            long ncpus = list.map!(a => a["Resource_List"]["ncpus"].integer).sum();
            double mem = list.map!(a => a["Resource_List"]["mem"].str.memBytes.to!double).sum();
            return tuple(len, ncpus, format("%6.1fGB", mem / 1E9));
        }

        auto totResource = aggregate(totJobs);
        auto runResource = aggregate(runJobs);

        auto fmt = "%10s\t%4d\t%4d\t%8s\t%4d\t%4d\t%8s";
        if(user == environment["USER"])
            fmt = fmt.color(fg.green);

        cwritefln(fmt, user, totResource.tupleof, runResource.tupleof);
    }

    writeln();


    // List of all user's jobs
    auto currUser = environment["USER"];
    writeln("Job ID\t\tS\ttCPU\ttMem\t\trMem\t\tvMem\t\tCPU(%)\tCPU Time\tWalltime");
    writeln("----------\t-\t----\t--------\t--------\t--------\t------\t----------\t----------");
    auto userJobs = jobList.getUserJobs(currUser).array.sort!q{a["key"].str < a["key"].str}.jobSort();
    foreach(job; userJobs) {
        // writeln(job["key"]);
        string id = job["key"].str;
        long tcpu = job["Resource_List"]["ncpus"].integer;
        string tmem = job["Resource_List"]["mem"].str.toGB;
        string jobS = job["job_state"].str;

        string rmem = "?";
        string vmem = "?";
        long cpupercent = 0;
        string cputime = "----:--:--";
        string walltime = "----:--:--";
        if(jobS == "R") {
            rmem = job["resources_used"]["mem"].str.toGB;
            vmem = job["resources_used"]["vmem"].str.toGB;
            cpupercent = job["resources_used"]["cpupercent"].integer;
            cputime = job["resources_used"]["cput"].str;
            walltime = job["resources_used"]["walltime"].str;
        }

        auto fmt = "%10s\t%1s\t%4s\t%8s\t%8s\t%8s\t%6s\t%10s\t%10s";
        if(jobS == "R")
            fmt = fmt.color(fg.green);

        cwritefln(fmt, id, jobS, tcpu, tmem, rmem, vmem, cpupercent, cputime, walltime);
    }
}
