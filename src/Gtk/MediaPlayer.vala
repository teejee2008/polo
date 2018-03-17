using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class MediaPlayer : AsyncTask{
	
	public MediaFile mFile;

	//playback state
	public bool is_muted = false;
    public bool is_paused = false;
    public bool is_idle = true;
	public double position = 0.0;
	public int volume = 70;
	
	//default state flags
    public bool mute_on_load = false;
    public bool pause_on_load = false;

	public uint window_id = 0;

	private string primary_player = "";

	public MediaPlayer(string _primary_player){
		
        is_muted = false;
        is_paused = false;
        is_idle = true;

        primary_player = _primary_player;

        init_regular_expressions();
	}

	private void init_regular_expressions(){
		
		regex_list = new Gee.HashMap<string, Regex>();
		
		try {
			//[CROP] Crop area: X: 4..1275  Y: 40..689  (-vf crop=1264:640:8:46).
			//[CROP] Crop area: X: 1..1279  Y: 40..699  (-vf crop=1264:656:10:42).
			regex_list["crop"] = new Regex("""-vf crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+)""");

			//  =====  PAUSE  =====
			regex_list["pause"] = new Regex("""=====  PAUSE  =====""");

			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			regex_list["av"] = new Regex("""A:[ \t]*([0-9.]+)[ \t]*V:[ \t]*([0-9.]+)[ \t]*""");

			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			regex_list["v"] = new Regex("""V:[ \t]*([0-9.]+)[ \t]*""");
			
			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			regex_list["a"] = new Regex("""A:[ \t]*([0-9.]+)[ \t]*""");

			//1.793458 no no 50
			regex_list["mpv"] = new Regex("""([0-9.]*) (yes|no) (yes|no) ([0-9.])""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void prepare() {
	
		string script_text = build_script();
		save_bash_script_temp(script_text, script_file);
	}

	private string build_script() {
		
		string cmd = primary_player;
		
		if (primary_player == "mpv"){
			
			//options
			cmd += " --no-config --no-quiet --idle=yes --keep-open=yes --terminal --no-msg-color --input-file=/dev/stdin --no-fs --hwdec=yes --sub-auto=fuzzy --panscan=1.0 --keepaspect --monitorpixelaspect=1 --stop-screensaver --no-input-default-bindings --input-vo-keyboard=no --no-input-cursor --cursor-autohide=no --osd-scale=1 --osd-level=0 --screenshot-format=jpg --ytdl=no";

			// --vo=xv --ao=alsa 
			
			//status line format
			cmd += " --term-status-msg='${=time-pos} ${pause} ${mute} ${volume}'";
			
			//window id
			cmd += " --wid=%u".printf(window_id);
		}
		else if (primary_player == "mplayer"){

			//options
			cmd += " -slave -noquiet -msglevel all=6 -nofs -idle -osdlevel 0 -colorkey 0x101010";
			
			//widowid
			cmd += " -wid %u".printf(window_id);
		}

        log_debug(cmd);

		return cmd;
	}

	// execution ----------------------------

	public void execute() {

		prepare();

		begin();

		if (status == AppStatus.RUNNING){
			
			
		}
	}

	public override void parse_stdout_line(string out_line){
	
		if (is_terminated) { return; }
		
		update_progress_parse_console_output(out_line);
	}
	
	public override void parse_stderr_line(string err_line){
	
		if (is_terminated) { return; }

		
		update_progress_parse_console_output(err_line);
	}

	public bool update_progress_parse_console_output (string line) {

		if ((line == null) || (line.length == 0)) { return true; }

		MatchInfo match;
		
		if (regex_list["mpv"].match(line, 0, out match)) {
			
			position = double.parse(match.fetch(1));
			is_paused = (match.fetch(2) == "yes") ? true : false;
			is_muted = (match.fetch(3) == "yes") ? true : false;
			volume = int.parse(match.fetch(4));
			//log_debug("rex_mpv");
		}
		else if (regex_list["av"].match(line, 0, out match)){
			
			position = double.parse(match.fetch(2));
			is_paused = false;
			//log_debug("rex_av");
		}
		else if (regex_list["v"].match(line, 0, out match)){
			
			position = double.parse(match.fetch(1));
			is_paused = false;
			//log_debug("rex_video");
		}
		else if (regex_list["a"].match(line, 0, out match)){
			
			position = double.parse(match.fetch(1));
			is_paused = false;
			//log_debug("rex_audio");
		}
		else if (regex_list["pause"].match(line, 0, out match)){

			is_paused = true;
		}
		else if (regex_list["crop"].match(line, 0, out match)){

			int w = int.parse(match.fetch(1));
			int h = int.parse(match.fetch(2));
			int x = int.parse(match.fetch(3));
			int y = int.parse(match.fetch(4));

			//log_debug("match=%d,%d,%d,%d".printf(w,h,x,y));
			
			int cropL = x;
			int cropR = mFile.SourceWidth - w - x;
			int cropT = y;
			int cropB = mFile.SourceHeight - h - y;
			
			if (cropL < mFile.CropL){
				mFile.CropL = cropL;
			}
			if (cropR < mFile.CropR){
				mFile.CropR = cropR;
			}
			if (cropT < mFile.CropT){
				mFile.CropT = cropT;
			}
			if (cropB < mFile.CropB){
				mFile.CropB = cropB;
			}
		}

		return true;
	}

	protected override void finish_task(){
		if ((status != AppStatus.CANCELLED) && (status != AppStatus.PASSWORD_REQUIRED)) {
			status = AppStatus.FINISHED;
		}
	}

	// actions ---------------------------------------
	
	public void start_player(string extra_options = ""){
		
		execute();

        sleep(500);
    }

	public void open_file(MediaFile _mFile, bool _pause, bool _mute, bool _loop, int _volume){

		log_debug("MediaPlayer: open_file(): muted: %s, paused: %s".printf(_mute.to_string(), _pause.to_string()));
		
		mFile = _mFile;

		if (!is_running){
			
			start_player();
		}

		string f = mFile.Path;
		//escape: \ \n "
        f = f.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
        f = "\"" + f + "\"";
        
		if (primary_player == "mpv"){
			
			write_stdin("loadfile %s".printf(f));
		}
		else{
			write_stdin("loadfile %s".printf(f));
		}
		
		if (_pause){
			sleep(100);
			framestep(); //'frame_step' will pause the video, 'pause' will toggle
		}
		
		if (_mute){
			sleep(100);
			mute();
		}
		
		if (_loop){
			loop_file();
		}

		if (_volume > 0){
			set_volume(_volume);
		}
	}

	public void loop_file(){
		
		if (primary_player == "mpv"){
			write_stdin("cycle loop 100 ");
		}
		else{
			write_stdin("loop 100 ");
		}
	}

	public void playback_pause(){
		
		framestep();
	}

	public void playback_unpause(){
		
		if (is_paused){
			toggle_pause();
		}
	}

	public void playback_stop(){
		
		write_stdin("stop ");
	}

	
	public void toggle_pause(){
		//pause/unpause
		if (primary_player == "mpv"){
			write_stdin("cycle pause ");
		}
		else{
			write_stdin("pause ");
		}
	}

	public void mute(){

		log_debug("mute()");
		
		if (primary_player == "mplayer"){
			write_stdin("mute 1");
		}
		else{
			write_stdin("cycle mute 1");
		}

		is_muted = true;
	}

	public void unmute(){

		log_debug("unmute()");
		
		if (primary_player == "mplayer"){
			write_stdin("mute 0");
		}
		else{
			write_stdin("cycle mute 1");
		}

		is_muted = false;
	}

	public void set_volume(int percent){
		
		volume = percent;
		
		if (primary_player == "mpv"){
			write_stdin("set volume %d".printf(volume));
		}
		else{
			write_stdin("volume %d 1".printf(volume));
		}
	}
	
	public void quit(){

		log_debug("MediaPlayer:quit()");
		
		write_stdin("quit ");
		
		stop();
	}

	public void toggle_fullscreen(){

		if (primary_player == "mplayer"){
			
			write_stdin("fullscreen 1");
		}
		else{
			write_stdin("cycle fullscreen 1");
		}
	}

	public void change_rect(int parameter, int amount){
		
		write_stdin("change_rectangle %d %d ".printf(parameter, amount));
	}

	public void update_rect_left(int change){
		
		change_rect(2, change);
		change_rect(0, -change);
		
		if (is_paused){
			framestep();
		}
	}

	public void update_rect_right(int change){
		
		//change_rect(2, change);
		change_rect(0, -change);
		
		if (is_paused){
			framestep();
		}
	}

	public void update_rect_top(int change){
		
		change_rect(3, change);
		
		change_rect(1, -change);
		
		if (is_paused){
			framestep();
		}
	}

	public void update_rect_bottom(int change){
		
		//change_rect(3, change);
		change_rect(1, -change);
		
		if (is_paused){
			framestep();
		}
	}

	public void Mpv_Crop(){
		
		int w = mFile.SourceWidth - mFile.CropL - mFile.CropR;
		int h = mFile.SourceHeight - mFile.CropT - mFile.CropB;
		int x = mFile.CropL;
		int y = mFile.CropT;
		
		write_stdin("vf set \"crop=%d:%d:%d:%d\"".printf(w,h,x,y));
	}
	
	public void framestep(){
		
		write_stdin("frame_step ");
	}

	public void set_rect(){
		
		change_rect(0, - mFile.CropL - mFile.CropR); //0=width
		framestep();
		
		change_rect(1, - mFile.CropT - mFile.CropB); //1=height
		framestep();
		
		change_rect(2, mFile.CropL); //2=x
		framestep();
		
		change_rect(3, mFile.CropT); //3=y
		framestep();
	}
	
	public void seek(double seconds){
		
		if (primary_player == "mpv"){
			
			write_stdin("seek %.1f absolute".printf(seconds));
		}
		else{
			write_stdin("seek %.1f 2".printf(seconds));
		}
	}

	public void exit(){
		
		write_stdin("quit ");
		
		process_kill(child_pid);
	}
}

