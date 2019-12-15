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
    return format!"%.1fGB"(memBytes(s) / 1E9);
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

        return format("%s--%06d", jobname, idx);
    }

    return r.array.sort!((a, b) => jobIden(a) < jobIden(b) ).array();
}


void writeHyphen(Writer)(auto ref Writer writer, const(char)[] fmt)
{
    auto fmtspec = FormatSpec!char(fmt);

    while(fmtspec.writeUpToNextSpec(writer)) {
        size_t width;
        if(fmtspec.nested) {
            // usersのため
            width = 10;
        }
        else
            width = fmtspec.width;

        foreach(i; 0 .. width)
            .put(writer, '-');
    }
}


void writeValues(Writer, T...)(auto ref Writer writer, bool leftalign, const(char)[] fmt, T args)
{
    auto fmtspec = FormatSpec!char(fmt);

    while(fmtspec.writeUpToNextSpec(writer)) {
        Lswitch: switch(fmtspec.indexStart) {
          static foreach(i, arg; args) {
            case i+1:
                typeof(arg) value = arg;
                static if(is(typeof(arg) : const(char)[])){
                    fmtspec.flDash = leftalign;
                    if(fmtspec.width != 0 && arg.length > fmtspec.width)
                        value = value[0 .. fmtspec.width];
                }

                static if(is(typeof(arg) : const(char)[]))
                {
                    if(fmtspec.nested is null)
                        formatValue(writer, value, fmtspec);
                    else {
                        // nodefmtにおけるusersはヘッダの表示時にはただの文字列として表示
                        formattedWrite(writer, "%s", value);
                    }
                }
                else
                {
                    formatValue(writer, value, fmtspec);
                }
                break Lswitch;
          }

            default:
                // writefln!"'%s'"(fmt[0 .. $ - fmtspec.trailing.length])
                stderr.writefln!"Format error:"();
                stderr.writefln!"Input: %s"(fmt);
                stderr.writef  !"Error: "();
                foreach(i; 0 .. fmt.length - fmtspec.trailing.length)
                    stderr.write(' ');
                stderr.writeln('^');
                enforce(0, "フォーマットが不正です");
        }
    }
}


string replaceFmtString(string fmt, in string[] arglist)
{
    foreach(i, e; arglist)
        fmt = fmt.replace('%' ~ e ~ ':', '%' ~ to!string(i+1) ~ '$');

    return fmt;
}


alias showNodesColumnNames = AliasSeq!("vnode", "njobs", "ncpus f/t", "mem f/t", "gpu", "users", "state");
immutable showNodesFmtList = ["name", "njobs", "cpu", "mem", "gpu", "users", "state"];
immutable defaultShowNodesFmt = "%name:6s  %state:8s  %njobs:5s  %cpu:9s  %mem:11s  %gpu:3s  %users:(%(%7s*%2d%), %)";

alias showUsersColumnNames = AliasSeq!("Username", "tJob", "tCPU", "tMem", "rJob", "rCPU", "rMem");
immutable showUsersFmtList = ["user", "tjob", "tcpu", "tmem", "rjob", "rcpu", "rmem"];
immutable defaultShowUsersFmt = "%user:10s  %tjob:4s  %tcpu:4s  %tmem:8s  %rjob:4s  %rcpu:4s  %rmem:8s";

alias showJobsColumnNames = AliasSeq!("Job ID", "Username", "S", "tCPU", "tMem", "rMem", "vMem", "CPU(%)", "CPU Time", "Walltime", "Jobname", "Queue", "C", "Container", "Image");
immutable showJobsFmtList = ["id", "user", "S", "tcpu", "tmem", "rmem", "vmem", "cpup", "cput", "walltime", "name", "queue", "C", "container", "image"];
immutable defaultShowJobsFmt =  "%id:10s  %user:10s  %queue:6s  %name:20s  %S:1s  %tcpu:4s  %tmem:8s  %rmem:8s  %vmem:8s  %cpup:6s  %cput:10s  %walltime:10s  %C:1s  %image:20s";


bool dontShowHeader;


void main(string[] args)
{
    bool showNodes, showUsers, showJobs, showOnlyMyJobs, showColored;
    string fmtShowNode = defaultShowNodesFmt;
    string fmtShowUsers = defaultShowUsersFmt;
    string fmtShowJobs = defaultShowJobsFmt;
    auto helpInformation = getopt(
        args,
        "n|node",   "ノードの情報を表示する",   &showNodes,
        "nodefmt",  "ノード情報を表示する際のフォーマット指定．デフォルト値：" ~ defaultShowNodesFmt,
                                            &fmtShowNode,
        "u|user",   "ユーザの情報を表示する",   &showUsers,
        "userfmt",  "ユーザ情報を表示する際のフォーマット指定．デフォルト値：" ~ defaultShowUsersFmt,
                                            &fmtShowUsers,
        "j|job",    "ジョブの情報を表示する",   &showJobs,
        "jobfmt",   "ジョブ情報を表示する際のフォーマット指定．デフォルト値：" ~ defaultShowJobsFmt,
                                            &fmtShowJobs,
        "m|mine",   "自身のジョブのみ表示する", &showOnlyMyJobs,
        "c|color",  "色付きで表示する",         &showColored,
        "noheader", "各表のヘッダを表示しない", &dontShowHeader);

    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("pbsnodesやqstatから得られるクラスタ計算機の情報を表示します",
            helpInformation.options);

        return;
    }

    if(!showNodes && !showUsers && !showJobs) {
        showNodes = true;
        showUsers = true;
        showJobs = true;
    }


    auto pbsnodesResult = execute(["pbsnodes", "-aSj", "-F", "json"]);
    enforce(pbsnodesResult.status == 0, "`pbsnodes -aSj` is failed.");

    auto nodeList = pbsnodesResult.output.parseJSON()["nodes"].object.byKeyValue.map!((a){
        a.value["key"] = a.key;
        return a.value;
    }).array().sort!q{a["key"].str < b["key"].str}.array();

    auto qstatResult = execute(["qstat", "-ft", "-F", "json"]);
    enforce(qstatResult.status == 0, "`qstat -ft -F json` is failed.");

    auto jobList = qstatResult.output.parseJSON()["Jobs"].object.byKeyValue.map!((a){
        a.value["key"] = a.key.replace(".xregistry0", "");
        return a.value;
    }).removeArrayJobParent.array();


    if(showNodes) {
        fmtShowNode = fmtShowNode.replaceFmtString(showNodesFmtList);
        showNodeInfo(nodeList, jobList, fmtShowNode, showColored);
        if(showUsers || showJobs) writeln();
    }

    if(showUsers) {
        fmtShowUsers = fmtShowUsers.replaceFmtString(showUsersFmtList);
        showUserInfo(nodeList, jobList, fmtShowUsers, showColored);
        if(showJobs) writeln();
    }

    if(showJobs) {
        fmtShowJobs = fmtShowJobs.replaceFmtString(showJobsFmtList);
        showJobInfo(nodeList, jobList, fmtShowJobs, showOnlyMyJobs, showColored);
    }
}


void showNodeInfo(in JSONValue[] nodeList, in JSONValue[] jobList, string fmtstr, bool showColored)
{
    if(! dontShowHeader) {
        writeValues(stdout.lockingTextWriter, true, fmtstr, showNodesColumnNames);
        writeln();
        writeHyphen(stdout.lockingTextWriter, fmtstr);
        writeln();
    }

    scope(success) {
        if(! dontShowHeader) {
            writeHyphen(stdout.lockingTextWriter, fmtstr);
            writeln();
        }
    }

    foreach(node; nodeList) {
        auto name = node["key"].str;
        auto jobids = node["jobs"].array.map!(a => a.str.replace(".xregistry0", "")).array().sort.uniq.array();
        auto njob = jobids.length;
        auto mem = node["mem f/t"].str;
        auto ncpus = node["ncpus f/t"].str;
        auto ngpus = node["ngpus f/t"].str;
        auto state = node["State"].str;

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

        auto usercpus = userCPUs.byKeyValue.map!(a => tuple(a.key, a.value)).array();

        auto fmt = fmtstr;
        if(showColored && (state != "free" || ncpus.startsWith("0/") || mem.startsWith("0gb/")) ) {
            fmt = fmt.color(fg.red);
        }

        writeValues(stdout.lockingTextWriter, false, fmt, name, njob, ncpus, mem, ngpus, usercpus, state);
        writeln();
    }
}


void showUserInfo(in JSONValue[] nodeList, in JSONValue[] jobList, string fmtstr, bool showColored)
{
    // List of all users
    auto userList = jobList.map!q{a["Variable_List"]["PBS_O_LOGNAME"].str}.array().sort().uniq.array();

    if(! dontShowHeader) {
        writeValues(stdout.lockingTextWriter, true, fmtstr, showUsersColumnNames);
        writeln();
        writeHyphen(stdout.lockingTextWriter, fmtstr);
        writeln();
    }

    scope(success) {
        if(! dontShowHeader) {
            writeHyphen(stdout.lockingTextWriter, fmtstr);
            writeln();
        }
    }

    foreach(user; userList) {
        auto totJobs = jobList.removeTerminatedJob().getUserJobs(user).array();
        auto runJobs = totJobs.filter!q{a["job_state"].str == "R"}.array();

        Tuple!(size_t, long, string) aggregate(in JSONValue[] list) {
            size_t len = list.length;
            long ncpus = list.map!(a => a["Resource_List"]["ncpus"].integer).sum();
            double mem = list.map!(a => a["Resource_List"]["mem"].str.memBytes.to!double).sum();
            return tuple(len, ncpus, format("%6.1fGB", mem / 1E9));
        }

        auto totResource = aggregate(totJobs);
        auto runResource = aggregate(runJobs);

        auto fmt = fmtstr;
        if(showColored && user == environment["USER"])
            fmt = fmt.color(fg.green);

        writeValues(stdout.lockingTextWriter, false, fmt, user, totResource.tupleof, runResource.tupleof);
        writeln();
    }
}


void showJobInfo(in JSONValue[] nodeList, in JSONValue[] jobList, string fmtstr, bool showOnlyMyJobs, bool showColored)
{
    auto currUser = environment["USER"];

    if(! dontShowHeader) {
        writeValues(stdout.lockingTextWriter, true, fmtstr, showJobsColumnNames);
        writeln();
        writeHyphen(stdout.lockingTextWriter, fmtstr);
        writeln();
    }

    scope(success) {
        if(! dontShowHeader) {
            writeHyphen(stdout.lockingTextWriter, fmtstr);
            writeln();
        }
    }

    foreach(job; jobList.dup.jobSort()) {
        // writeln(job["key"]);
        string id = job["key"].str;
        long tcpu = job["Resource_List"]["ncpus"].integer;
        string tmem = job["Resource_List"]["mem"].str.toGB;
        string jobS = job["job_state"].str;
        string user = job["Variable_List"]["PBS_O_LOGNAME"].str;
        string jobname = job["Job_Name"].str;
        string queue = job["queue"].str;
        string containerType;
        string containerImage;
        if("SINGULARITY_IMAGE" in job["Variable_List"]) {
            containerType = "Singularity";
            containerImage = job["Variable_List"]["SINGULARITY_IMAGE"].str;
        } else if ("DOCKER_IMAGE" in job["Variable_List"]) {
            containerType = "Docker";
            containerImage = job["Variable_List"]["DOCKER_IMAGE"].str;
        }

        // アレイジョブのうち，終わっているジョブの表示はしない
        if(jobS == "X")
            continue;

        // -mオプションが渡されたときは自身のジョブ以外は表示しない
        if(showOnlyMyJobs && user != currUser)
            continue;

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

        auto fmt = fmtstr;
        if(showColored && showOnlyMyJobs && jobS == "R") {
            fmt = fmt.color(fg.green);
        } else if(showColored && !showOnlyMyJobs && user == currUser) {
            fmt = fmt.color(fg.green);
        }

        writeValues(stdout.lockingTextWriter, false,
            fmt, id, user, jobS, tcpu, tmem,
            rmem, vmem, cpupercent, cputime, walltime, jobname, queue,
            containerType[0 .. 1], containerType, containerImage);
        writeln();
    }
}
