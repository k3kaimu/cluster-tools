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


size_t writeValue(Writer, T)(auto ref Writer writer, auto ref T value, auto ref FormatSpec!char fmtspec)
{
    auto app = appender!string;
    app.formatValue(value, fmtspec);
    .put(writer, app.data);
    return app.data.length;
}


size_t[] writeValues(Writer, T...)(auto ref Writer writer, const(char)[] fmt, T args)
{
    auto fmtspec = FormatSpec!char(fmt);

    size_t[] writeLength;
    while(fmtspec.writeUpToNextSpec(writer)) {
        Lswitch: switch(fmtspec.indexStart) {
          static foreach(i, arg; args) {
            case i+1:
                auto app = appender!string();
                app.writeValue(arg, fmtspec);
                string str = app.data;
                if(fmtspec.width != 0)
                    str = str[0 .. min(fmtspec.width, $)];

                writeLength ~= str.length;
                .put(writer, str);
                break Lswitch;
          }

            default:
                stderr.writefln!"Format error:"();
                stderr.writefln!"Input: %s"(fmt);
                stderr.writef  !"Error: "();
                foreach(i; 0 .. fmt.length - fmtspec.trailing.length)
                    stderr.write(' ');
                stderr.writeln('^');
                enforce(0, "フォーマットが不正です");
        }
    }

    return writeLength;
}


void writeColumnHeader(T, Writer)(auto ref Writer writer, const(char)[] fmt, size_t[] collens)
{
    string[] headers = getColumnNames!T();

    auto fmtspec = FormatSpec!char(fmt);
    while(fmtspec.writeUpToNextSpec(writer)) {
        auto width = collens[0];
        collens.popFront();

        string h = headers[fmtspec.indexStart-1];
        .put(writer, h[0 .. min(width, $)]);
        if(width > h.length) {
            foreach(i; 0 .. width - h.length)
                .put(writer, ' ');
        }
    }
}


void writeColumnHyphen(Writer)(auto ref Writer writer, const(char)[] fmt, size_t[] collens)
{
    auto fmtspec = FormatSpec!char(fmt);
    while(fmtspec.writeUpToNextSpec(writer)) {
        auto width = collens[0];
        collens.popFront();

        foreach(i; 0 .. width)
            .put(writer, '-');
    }
}


string replaceFmtString(T)(string fmt)
{
    foreach(i, e; getIdentNames!T)
        fmt = fmt.replace('%' ~ e ~ ':', '%' ~ to!string(i+1) ~ '$');

    return fmt;
}


struct InfoTag
{
    string ident;
    string name;
}


struct NodeInfo
{
    @InfoTag("name",   "vnode")         string vnode;
    @InfoTag("njobs",  "njobs")         long njobs;
    @InfoTag("cpu",    "ncpus f/t")     string cpu;
    @InfoTag("mem",    "mem f/t")       string mem;
    @InfoTag("gpu",    "gpu")           string gpu;
    @InfoTag("users",  "users")         Tuple!(string, long)[] users;
    @InfoTag("state",  "state")         string state;
}


struct UserInfo
{
    @InfoTag("user",   "Username")      string user;
    @InfoTag("tjob",   "tJob")          long tjob;
    @InfoTag("tcpu",   "tCPU")          long tcpu;
    @InfoTag("tmem",   "tMem")          string tmem;
    @InfoTag("rjob",   "rJob")          long rjob;
    @InfoTag("rcpu",   "rCPU")          long rcpu;
    @InfoTag("rmem",   "rMem")          string rmem;
}

struct JobInfo
{
    @InfoTag("id",         "Job ID")        string id;
    @InfoTag("user",       "Username")      string user;
    @InfoTag("S",          "S")             string state;
    @InfoTag("tcpu",       "tCPU")          long tcpu;
    @InfoTag("tmem",       "tMem")          string tmem;
    @InfoTag("rmem",       "rMem")          string rmem;
    @InfoTag("vmem",       "vMem")          string vmem;
    @InfoTag("cpup",       "CPU(%)")        long cpup;
    @InfoTag("cput",       "CPU Time")      string cputime;
    @InfoTag("walltime",   "Walltime")      string walltime;
    @InfoTag("name",       "Job Name")      string name;
    @InfoTag("queue",      "Queue")         string queue;
    @InfoTag("C",          "C")             string C;
    @InfoTag("container",  "Container")     string containerType;
    @InfoTag("image",      "Image")         string image;
}

string[] getIdentNames(T)()
{
    string[] dst;
    static foreach(sym; getSymbolsByUDA!(T, InfoTag)) {
        dst ~= getUDAs!(sym, InfoTag)[0].ident;
    }

    return dst;
}


string[] getColumnNames(T)()
{
    string[] dst;
    static foreach(sym; getSymbolsByUDA!(T, InfoTag)) {
        dst ~= getUDAs!(sym, InfoTag)[0].name;
    }

    return dst;
}


immutable defaultShowNodesFmt = "%name:6s  %state:8s  %njobs:5s  %cpu:9s  %mem:11s  %gpu:3s  %users:(%(%7s*%2d%), %)";
immutable defaultShowUsersFmt = "%user:10s  %tjob:4s  %tcpu:4s  %tmem:8s  %rjob:4s  %rcpu:4s  %rmem:8s";
immutable defaultShowJobsFmt =  "%id:10s  %user:10s  %queue:6s  %name:20s  %S:1s  %tcpu:4s  %tmem:8s  %rmem:8s  %vmem:8s  %cpup:6s  %cput:10s  %walltime:10s  %container:1s  %image:20s";


void main(string[] args)
{
    bool showNodes, showUsers, showJobs, showOnlyMyJobs, showColored, dontShowHeader;
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
        fmtShowNode = fmtShowNode.replaceFmtString!NodeInfo();
        auto nodeInfo = makeNodeInfo(nodeList, jobList);
        showInfo(fmtShowNode, nodeInfo, dontShowHeader, showColored,
            ColorSetting!NodeInfo(a => a.state != "free" || a.cpu.startsWith("0/") || a.mem.startsWith("0gb/"), fg.red)
        );
        if(showUsers || showJobs) writeln();
    }

    if(showUsers) {
        fmtShowUsers = fmtShowUsers.replaceFmtString!UserInfo();
        auto userInfo = makeUserInfo(nodeList, jobList);
        showInfo(fmtShowUsers, userInfo, dontShowHeader, showColored,
            ColorSetting!UserInfo(a => a.user == environment["USER"], fg.green)
        );
        if(showJobs) writeln();
    }

    if(showJobs) {
        fmtShowJobs = fmtShowJobs.replaceFmtString!JobInfo();
        auto jobInfo = makeJobInfo(nodeList, jobList);
        if(showOnlyMyJobs)
            jobInfo = jobInfo.filter!(a => a.user == environment["USER"]).array();

        showInfo(fmtShowJobs, jobInfo, dontShowHeader, showColored,
            ColorSetting!JobInfo(a => a.user == environment["USER"] && (a.state == "R" || !showOnlyMyJobs) , fg.green)
        );
    }
}


NodeInfo[] makeNodeInfo(in JSONValue[] nodeList, in JSONValue[] jobList)
{
    NodeInfo[] dst;
    foreach(node; nodeList) {
        NodeInfo info;
        info.vnode = node["key"].str;
        auto jobids = node["jobs"].array.map!(a => a.str.replace(".xregistry0", "")).array().sort.uniq.array();
        info.njobs = jobids.length;
        info.mem = node["mem f/t"].str;
        info.cpu = node["ncpus f/t"].str;
        info.gpu = node["ngpus f/t"].str;
        info.state = node["State"].str;

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

        info.users = userCPUs.byKeyValue.map!(a => tuple(a.key, a.value)).array();
        dst ~= info;
    }

    return dst;
}


UserInfo[] makeUserInfo(in JSONValue[] nodeList, in JSONValue[] jobList)
{
    // List of all users
    auto userList = jobList.map!q{a["Variable_List"]["PBS_O_LOGNAME"].str}.array().sort().uniq.array();

    UserInfo[] dst;
    foreach(user; userList) {
        UserInfo info;
        info.user = user;
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

        info.tjob = totResource[0];
        info.tcpu = totResource[1];
        info.tmem = totResource[2];

        info.rjob = runResource[0];
        info.rcpu = runResource[1];
        info.rmem = runResource[2];

        dst ~= info;
    }

    return dst;
}


JobInfo[] makeJobInfo(in JSONValue[] nodeList, in JSONValue[] jobList)
{
    JobInfo[] dst;
    foreach(job; jobList.dup.jobSort()) {
        JobInfo info;
        // writeln(job["key"]);
        info.id = job["key"].str;
        info.tcpu = job["Resource_List"]["ncpus"].integer;
        info.tmem = job["Resource_List"]["mem"].str.toGB;
        info.state = job["job_state"].str;
        info.user = job["Variable_List"]["PBS_O_LOGNAME"].str;
        info.name = job["Job_Name"].str;
        info.queue = job["queue"].str;
        if("SINGULARITY_IMAGE" in job["Variable_List"]) {
            info.containerType = "Singularity";
            info.image = job["Variable_List"]["SINGULARITY_IMAGE"].str;
        } else if ("DOCKER_IMAGE" in job["Variable_List"]) {
            info.containerType = "Docker";
            info.image = job["Variable_List"]["DOCKER_IMAGE"].str;
        }
        info.C = info.containerType[0 .. 1];

        info.rmem = "?";
        info.vmem = "?";
        info.cpup = 0;
        info.cputime = "----:--:--";
        info.walltime = "----:--:--";
        if(info.state == "R") {
            info.rmem = job["resources_used"]["mem"].str.toGB;
            info.vmem = job["resources_used"]["vmem"].str.toGB;
            info.cpup = job["resources_used"]["cpupercent"].integer;
            info.cputime = job["resources_used"]["cput"].str;
            info.walltime = job["resources_used"]["walltime"].str;
        }

        dst ~= info;
    }

    return dst;
}


struct ColorSetting(T)
{
    bool delegate(T) pred;
    typeof(fg.red) color;
}


void showInfo(Info)(string fmtstr, Info[] list, bool dontShowHeader, bool showColored, ColorSetting!Info[] colorSettings...)
{
    string[] lines;
    size_t[] collens;
    foreach(info; list) {
        auto fmt = fmtstr;
        foreach(cs; colorSettings) {
            if(showColored && cs.pred(info)) {
                fmt = fmt.color(cs.color);
            }
        }

        auto app = appender!string();
        auto lens = writeValues(app, fmt, info.tupleof);
        lines ~= app.data;

        if(collens.length == 0)
            collens = lens;

        foreach(i, ref e; collens)
            e = max(e, lens[i]);
    }

    if(! dontShowHeader) {
        writeColumnHeader!Info(stdout.lockingTextWriter, fmtstr, collens);
        writeln();
        writeColumnHyphen(stdout.lockingTextWriter, fmtstr, collens);
        writeln();
    }

    foreach(line; lines)
        writeln(line);

    if(! dontShowHeader) {
        writeColumnHyphen(stdout.lockingTextWriter, fmtstr, collens);
        writeln();
    }
}
