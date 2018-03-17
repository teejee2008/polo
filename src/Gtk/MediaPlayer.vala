using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.ProcessHelper;
using TeeJee.Misc;

public class MediaPlayer : GLib.Object{
	
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
	//public string input_pipe = "";
	
    public string err_line;
	public string out_line;
	public string status_line;
	public string status_summary;
	public Gee.ArrayList<string> stdout_lines;
	public Gee.ArrayList<string> stderr_lines;
	public Pid proc_id;
	public DataInputStream dis_out;
	public DataInputStream dis_err;
	public DataOutputStream dos_inp;
	public int64 progress_count;
	public int64 progress_total;
	public bool is_running;
	public int process_id = 0;
	
	public int CropL = 0;
	public int CropR = 0;
	public int CropT = 0;
	public int CropB = 0;

	private Regex rex_crop;
	private Regex rex_pause;
	private Regex rex_av;
	private Regex rex_audio;
	private Regex rex_video;
	private Regex rex_mpv;

	private string primary_player = "";

	public MediaPlayer(string _primary_player){
		
        is_muted = false;
        is_paused = false;
        is_idle = true;

        primary_player = _primary_player;

        try{
			//[CROP] Crop area: X: 4..1275  Y: 40..689  (-vf crop=1264:640:8:46).
			//[CROP] Crop area: X: 1..1279  Y: 40..699  (-vf crop=1264:656:10:42).
			rex_crop = new Regex("""-vf crop=([0-9]+):([0-9]+):([0-9]+):([0-9]+)""");

			//  =====  PAUSE  =====
			rex_pause = new Regex("""=====  PAUSE  =====""");

			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			rex_av = new Regex("""A:[ \t]*([0-9.]+)[ \t]*V:[ \t]*([0-9.]+)[ \t]*""");

			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			rex_video = new Regex("""V:[ \t]*([0-9.]+)[ \t]*""");
			
			//A:   1.9 V:   1.9 A-V:  0.001 ct:  0.000   0/  0  1%  1%  0.4% 0 0
			rex_audio = new Regex("""A:[ \t]*([0-9.]+)[ \t]*""");

			//1.793458 no no 50
			rex_mpv = new Regex("""([0-9.]*) (yes|no) (yes|no) ([0-9.])""");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public void start_player(string extra_options = ""){
		
		string args = primary_player;
		
		if (primary_player == "mpv"){
			
			//options
			args += " --no-config --no-quiet --idle=yes --keep-open=yes --terminal --no-msg-color --input-file=/dev/stdin --no-fs --hwdec=yes --sub-auto=fuzzy --panscan=1.0 --keepaspect --monitorpixelaspect=1 --stop-screensaver --no-input-default-bindings --input-vo-keyboard=no --no-input-cursor --cursor-autohide=no --osd-scale=1 --osd-level=0 --screenshot-format=jpg --ytdl=no";

			// --vo=xv --ao=alsa 
			
			//status line format
			args += " --term-status-msg='${=time-pos} ${pause} ${mute} ${volume}'";
			
			//window id
			args += " --wid=%u".printf(window_id);
		}
		else if (primary_player == "mplayer"){

			//options
			args += " -slave -noquiet -msglevel all=6 -nofs -idle -osdlevel 0 -colorkey 0x101010";
			
			//widowid
			args += " -wid %u".printf(window_id);
		}

		if (extra_options.length > 0){
			args += " " + extra_options.strip();
		}

        log_debug(args);

        run(args);

        sleep(500);
    }

    private bool run (string cmd) {
		
		string[] argv = new string[1];
		argv[0] = save_bash_script_temp(cmd);

		Pid child_pid;
		int input_fd;
		int output_fd;
		int error_fd;

		string working_dir = TEMP_DIR + "/" + timestamp_for_path();
		dir_create(working_dir);
		
		try {
			//execute script file
			Process.spawn_async_with_pipes(
			    working_dir, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    out child_pid,
			    out input_fd,
			    out output_fd,
			    out error_fd);

			is_running = true;

			process_id = child_pid;

			//create stream readers
			var uis_out = new UnixInputStream(output_fd, false);
			var uis_err = new UnixInputStream(error_fd, false);
			var uos_inp = new UnixOutputStream(input_fd, false);
			dis_out = new DataInputStream(uis_out);
			dis_err = new DataInputStream(uis_err);
			dos_inp = new DataOutputStream(uos_inp);
			dis_out.newline_type = DataStreamNewlineType.ANY;
			dis_err.newline_type = DataStreamNewlineType.ANY;
			//dos_inp.newline_type = DataStreamNewlineType.ANY;

			try {
				//start thread for reading output stream
				Thread.create<void> (read_output_line, true);
			} catch (Error e) {
				log_error (e.message);
			}

			try {
				//start thread for reading error stream
				Thread.create<void> (read_error_line, true);
			} catch (Error e) {
				log_error (e.message);
			}

			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	private void read_error_line() {
		
		try {
			err_line = dis_err.read_line (null);
			
			while (is_running && (err_line != null)) {

				parse_line(err_line);

				//log_debug("err:" + err_line);
				err_line = dis_err.read_line (null); //read next
			}

			log_debug("stderr reader exited");
		}
		catch (Error e) {
			log_debug("In read_error_line()");
			log_error (e.message);
		}
	}

	private void parse_line(string line){

		MatchInfo match;
		
		if (rex_mpv.match(line, 0, out match)){
			position = double.parse(match.fetch(1));
			is_paused = (match.fetch(2) == "yes") ? true : false;
			is_muted = (match.fetch(3) == "yes") ? true : false;
			volume = int.parse(match.fetch(4));
			//log_debug("rex_mpv");
		}
		else if (rex_av.match(line, 0, out match)){
			position = double.parse(match.fetch(2));
			is_paused = false;
			//log_debug("rex_av");
		}
		else if (rex_video.match(line, 0, out match)){
			position = double.parse(match.fetch(1));
			is_paused = false;
			//log_debug("rex_video");
		}
		else if (rex_audio.match(line, 0, out match)){
			position = double.parse(match.fetch(1));
			is_paused = false;
			//log_debug("rex_audio");
		}
		else if (rex_pause.match(line, 0, out match)){
			is_paused = true;
			//log_debug("rex_pause");
		}
		else{
			//log_debug("no-match");
		}
	}

	private void read_output_line() {
		
		try {
			
			out_line = dis_out.read_line (null);
			
			while (is_running && (out_line != null)) {

				parse_line(out_line);

				/*if (rex_crop.match (out_line, 0, out match)){
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
				}*/

				//log_debug("out:" + out_line);
				out_line = dis_out.read_line (null);  //read next
			}

			//is_running = false;

			//input_pipe = "";
			log_debug("stdout reader exited");
		}
		catch (Error e) {
			log_debug("In read_output_line()");
			log_error (e.message);
		}
	}

	private void write_to_stdin(string line) {
		
		try {
			if (is_running){
				log_debug(line);
				dos_inp.put_string(line + "\n");
				dos_inp.flush();
			}
		}
		catch (Error e) {
			log_debug("In write_to_stdin()");
			log_error (e.message);
		}
	}

	public void open_file(MediaFile _mFile, bool _pause, bool _mute, bool _loop){

		log_debug("MediaPlayer: open_file(): muted: %s, paused: %s".printf(_mute.to_string(), _pause.to_string()));
		
		mFile = _mFile;

		if (!process_is_running(process_id)){
			
			start_player();
		}

		string f = mFile.Path;
		//escape: \ \n "
        f = f.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
        f = "\"" + f + "\"";
        
		if (primary_player == "mpv"){
			
			write_to_stdin("loadfile %s".printf(f));
		}
		else{
			write_to_stdin("loadfile %s".printf(f));
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
	}

	public void loop_file(){
		
		if (primary_player == "mpv"){
			write_to_stdin("cycle loop 100 ");
		}
		else{
			write_to_stdin("loop 100 ");
		}
	}

	public void pause(){
		framestep();
	}

	public void unpause(){
		if (is_paused){
			toggle_pause();
		}
	}
	
	public void toggle_pause(){
		//pause/unpause
		if (primary_player == "mpv"){
			write_to_stdin("cycle pause ");
		}
		else{
			write_to_stdin("pause ");
		}
	}

	public void mute(){

		log_debug("mute()");
		
		if (primary_player == "mplayer"){
			write_to_stdin("mute 1");
		}
		else{
			write_to_stdin("cycle mute 1");
		}

		is_muted = true;
	}

	public void unmute(){

		log_debug("unmute()");
		
		if (primary_player == "mplayer"){
			write_to_stdin("mute 0");
		}
		else{
			write_to_stdin("cycle mute 1");
		}

		is_muted = false;
	}

	public void set_volume(int percent){
		
		volume = percent;
		
		if (primary_player == "mpv"){
			write_to_stdin("set volume %d".printf(volume));
		}
		else{
			write_to_stdin("volume %d 1".printf(volume));
		}
	}
	
	public void stop(){
		
		write_to_stdin("stop ");
	}

	public void quit(){

		log_debug("MediaPlayer:quit()");
		
		write_to_stdin("quit ");
		
		if (process_is_running(process_id)){
			process_kill(process_id);
		}
	}

	public void toggle_fullscreen(){

		if (primary_player == "mplayer"){
			
			write_to_stdin("fullscreen 1");
		}
		else{
			write_to_stdin("cycle fullscreen 1");
		}
	}

	public void change_rect(int parameter, int amount){
		
		write_to_stdin("change_rectangle %d %d ".printf(parameter, amount));
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
		
		write_to_stdin("vf set \"crop=%d:%d:%d:%d\"".printf(w,h,x,y));
	}
	
	public void framestep(){
		
		write_to_stdin("frame_step ");
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
			
			write_to_stdin("seek %.1f absolute".printf(seconds));
		}
		else{
			write_to_stdin("seek %.1f 2".printf(seconds));
		}
	}

	public void exit(){
		
		write_to_stdin("quit ");
		
		is_running = false;
		
		process_kill(proc_id);
	}
}

