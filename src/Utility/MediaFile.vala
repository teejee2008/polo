using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.MediaInfo;
using TeeJee.System;
using TeeJee.Misc;

public class MediaFile : GLib.Object{
	public string Path;
	public string Name;
	public string Title;
	public string Extension;
	public string Location;

	public int64 Size = 0;
	public long Duration = 0; //in milliseconds
	public string ThumbnailImagePath = "";

	public string TrackName = "";
	public string TrackNumber = "";
	public string Album = "";
	public string Artist = "";
	public string Genre = "";
	public string RecordedDate = "";
	public string Comment = "";

	public int CropL = 0;
	public int CropR = 0;
	public int CropT = 0;
	public int CropB = 0;
	public bool AutoCropError = false;

	public double StartPos = 0.0;
	public double EndPos = 0.0;
	public Gee.ArrayList<MediaClip> clip_list;
	
	public Gee.ArrayList<MediaStream> stream_list;
	public Gee.ArrayList<AudioStream> audio_list;
	public Gee.ArrayList<VideoStream> video_list;
	public Gee.ArrayList<TextStream> text_list;
	
	//public FileStatus Status = FileStatus.PENDING;
	public bool IsValid;
	public string ProgressText = _("Queued");
	public int ProgressPercent = 0;

	public string InfoText = "";
	public string InfoTextFormatted = "";
	
	public string FileFormat = "";
	public string VideoFormat = "";
	public string AudioFormat = "";
	public int SourceWidth = 0;
	public int SourceHeight = 0;
	public double SourceFrameRate = 0;
	public int AudioChannels = 0;
	public int AudioSampleRate = 0;
	public int AudioBitRate = 0;
	public int VideoBitRate = 0;
	public int BitRate = 0;

	public string TempScriptFile;
	public string TempDirectory = "";
	public string LogFile = "";
	public string OutputFilePath = "";
	public long OutputFrameCount = 0;

	public static int ThumbnailWidth = 80; 
	public static int ThumbnailHeight= 64;

	public MediaFile(string filePath){
		IsValid = false;
		if (file_exists (filePath) == false) { return; }

		clip_list = new Gee.ArrayList<MediaClip>();
		stream_list = new Gee.ArrayList<MediaStream>();
		audio_list = new Gee.ArrayList<AudioStream>();
		video_list = new Gee.ArrayList<VideoStream>();
		text_list = new Gee.ArrayList<TextStream>();
		
		// set file properties ------------

		File f = File.new_for_path (filePath);
		File fp = f.get_parent();

		Path = filePath;
		Name = f.get_basename();
		Title = Name[0: Name.last_index_of(".",0)];
		Extension = Name[Name.last_index_of(".",0):Name.length];
		Location = fp.get_path();
		//stderr.printf(@"file=$filePath, name=$Name, title=$Title, ext=$Extension, dir=$Location\n");

		FileInfo fi = null;

		try{
			fi = f.query_info ("%s".printf(FileAttribute.STANDARD_SIZE), FileQueryInfoFlags.NONE, null);
			Size = fi.get_size();
		}
		catch (Error e) {
			log_error (e.message);
		}

		// get media information ----------

		query_mediainfo();
		if (Duration == 0) { return; }

		// search for subtitle files ---------------

		try{
	        var enumerator = fp.enumerate_children ("%s,%s,%s".printf(FileAttribute.STANDARD_NAME,FileAttribute.STANDARD_TYPE,FileAttribute.STANDARD_SIZE), 0);
			var fileInfo = enumerator.next_file();
	        while (fileInfo != null) {
	            if (fileInfo.get_file_type() == FileType.REGULAR) {
		            string fname = fileInfo.get_name().down();

		            if (fname.has_prefix(Title.down()) && (fname.has_suffix (".srt")||fname.has_suffix (".sub")||fname.has_suffix (".ssa")||fname.has_suffix (".ass")||fname.has_suffix (".ttxt")||fname.has_suffix (".xml")||fname.has_suffix (".lrc")))
		            {
						var stream = new TextStream();
						stream_list.add(stream);
	                	text_list.add(stream);
	                	stream.TypeIndex = text_list.index_of(stream);

						if (fname.has_suffix (".srt")){
							stream.Format = "SRT";
						}
						else if (fname.has_suffix (".ssa")){
							stream.Format = "SSA";
						}
						else if (fname.has_suffix (".ass")){
							stream.Format = "ASS";
						}
						else if (fname.has_suffix (".sub")){
							stream.Format = "SUB";
						}
						else if (fname.has_suffix (".ttxt")){
							stream.Format = "TTXT";
						}
						else if (fname.has_suffix (".lrc")){
							stream.Format = "LRC";
						}
						else if (fname.has_suffix (".xml")){
							stream.Format = "XML";
						}

	                	stream.SubName = fileInfo.get_name();
						stream.SubFile = Location + "/" + stream.SubName;
	                	stream.SubExt = stream.SubFile[stream.SubFile.last_index_of(".",0):stream.SubFile.length].down();
	                	stream.StreamSize = fileInfo.get_size();
	                	stream.get_character_encoding();
					
	                	// try to parse language info from subtitle file name

	                	var SubtitleTitle = stream.SubName[0: stream.SubName.last_index_of(".",0)];
	                	//log_msg("sub=%s".printf(SubtitleTitle));
	                	
	                	if (SubtitleTitle.length > Title.length){
							string lang = SubtitleTitle.down();
							lang = lang[Title.length:SubtitleTitle.length];
							lang = lang.replace("_","").replace("-","").strip();

							//log_msg("lang='%s',length=%d".printf(lang,lang.length));
							
							if (lang.length == 2){
								if (LanguageCodes.map_2_to_3.has_key(lang)){
									stream.LangCode = lang;
									stream.Title = LanguageCodes.map_2_to_Name[lang];
								}
							}
							else if (lang.length == 3){
								if (LanguageCodes.map_3_to_2.has_key(lang)){
									stream.LangCode = LanguageCodes.map_3_to_2[lang];
									stream.Title = LanguageCodes.map_3_to_Name[lang];
								}
							}
						}
	                	//log ("file=%s, name=%s, ext=%s\n".printf(SubFile, SubName, SubExt));
	                }
	            }
	            fileInfo = enumerator.next_file();
	        }
        }
        catch(Error e){
	        log_error (e.message);
	    }

		log_debug("streams=%d, video=%d, audio=%d".printf(stream_list.size, video_list.size, audio_list.size));
		
	    // get thumbnail ---------

	    //generate_thumbnail();

		IsValid = true;
	}

	public void query_mediainfo(){
		InfoText = get_mediainfo (Path, true);

		if (InfoText == null || InfoText == ""){
			return;
		}

		string sectionType = "";
		MediaStream stream = null;
		
		foreach (string line in InfoText.split ("\n")){
			if (line == null || line.length == 0) { continue; }

			if (line.contains (":") == false){
				if (line.contains ("Audio")){
					stream = new AudioStream();
					stream_list.add(stream);
					stream.Index = stream_list.index_of(stream) - 1; //-1 to ignore GeneralStream

					var audio = stream as AudioStream;
					audio_list.add(audio);
					audio.TypeIndex = audio_list.index_of(audio);
					
					sectionType = "audio";
					//HasAudio = true;
				}
				else if (line.contains ("Video")){
					stream = new VideoStream();
					stream_list.add(stream);
					stream.Index = stream_list.index_of(stream) - 1; //-1 to ignore GeneralStream

					var video = stream as VideoStream;
					video_list.add(video);
					video.TypeIndex = video_list.index_of(video);

					sectionType = "video";
					//HasVideo = true;
				}
				else if (line.contains ("General")){
					stream = new GeneralStream();
					stream_list.add(stream);

					sectionType = "general";
				}
				else if (line.contains ("Text")){
					stream = new TextStream();
					stream_list.add(stream);
					stream.Index = stream_list.index_of(stream) - 1; //-1 to ignore GeneralStream

					var text = stream as TextStream;
					text_list.add(text);
					text.TypeIndex = text_list.index_of(text);
					
					sectionType = "text";
					//HasSubs = true;
				}
			}
			else{
				string[] arr = line.split (": ");
				if (arr.length != 2) { continue; }

				string key = arr[0].strip();
				string val = arr[1].strip();

				if (sectionType	== "general"){
					switch (key.down()) {
						case "duration/string":
							Duration = parse_duration(val);
							break;
						case "track":
							TrackName = val;
							break;
						case "track/position":
							TrackNumber = val;
							break;
						case "album":
							Album = val;
							break;
						case "performer":
							Artist = val;
							break;
						case "genre":
							Genre = val;
							break;
						case "recorded_date":
							RecordedDate = val;
							break;
						case "comment":
							Comment = val;
							break;
						case "format":
							FileFormat = val;
							break;
						case "overallbitrate/string":
							BitRate = int.parse(val.split(" ")[0].strip());
							break;
					}
				}
				else if (sectionType == "video"){
					var video = stream as VideoStream;
					switch (key.down()) {
						case "duration/string":
							video.Duration = parse_duration(val);
							break;
						case "width/string":
							SourceWidth = int.parse(val.split(" ")[0].strip());
							video.Width = SourceWidth;
							break;
						case "height/string":
							SourceHeight = int.parse(val.split(" ")[0].strip());
							video.Height = SourceHeight;
							break;
						case "framerate/string":
						case "framerate_original/string":
							SourceFrameRate = double.parse(val.split(" ")[0].strip());
							video.FrameRate = SourceFrameRate;
							break;
						case "format":
							VideoFormat = val;
							video.Format = VideoFormat;
							break;
						case "bitrate/string":
						case "bitrate_nominal/string":
							VideoBitRate = int.parse(val.split(" ")[0].strip());
							video.BitRate = VideoBitRate;
							break;
						case "streamsize/string":
							double d = double.parse(val.split(" ")[0].strip());
							if (val.contains("GiB")){
								d = d * 1024 * 1024 * 1024;
							}
							else if (val.contains("MiB")){
								d = d * 1024 * 1024;
							}
							else if (val.contains("KiB")){
								d = d * 1024 ;
							}
							video.StreamSize = (int64) d;
							break;
					}
				}
				else if (sectionType == "audio"){
					var audio = stream as AudioStream;
					switch (key.down()) {
						case "duration/string":
							audio.Duration = parse_duration(val);
							break;
						case "channel(s)/string":
							AudioChannels = int.parse(val.split(" ")[0].strip());
							audio.Channels = AudioChannels;
							break;
						case "samplingrate/string":
							AudioSampleRate = (int)(double.parse(val.split(" ")[0].strip()) * 1000);
							audio.SampleRate = AudioSampleRate;
							break;
						case "format":
							AudioFormat = val;
							audio.Format = AudioFormat;
							break;
						case "bitrate/string":
						case "bitrate_nominal/string":
							AudioBitRate = int.parse(val.split(" ")[0].strip());
							audio.BitRate = AudioBitRate;
							break;
						case "language/string":
							audio.LangCode = val.split(" ")[0].strip().down();
							break;
						case "streamsize/string":
							double d = double.parse(val.split(" ")[0].strip());
							if (val.contains("GiB")){
								d = d * 1024 * 1024 * 1024;
							}
							else if (val.contains("MiB")){
								d = d * 1024 * 1024;
							}
							else if (val.contains("KiB")){
								d = d * 1024 ;
							}
							audio.StreamSize = (int64) d;
							break;
					}
				}
				else if (sectionType == "text"){
					var text = stream as TextStream;
					switch (key.down()) {
						case "format":
							text.Format = val;
							break;
						case "language/string":
							text.LangCode = val.down();
							break;
						case "title":
							text.Title = val;
							break;
					}
				}
			}
		}

		//set derived properties
		foreach(var st in stream_list){
			if (st is VideoStream){				
				var video = st as VideoStream;
				if ((video.StreamSize == 0) && (video.Duration > 0) && (video.BitRate > 0)){
					video.StreamSize = (int64) ((video.Duration / 1000.0) * video.BitRate * 1000.0 / 8);
				}
				//log_msg("dur=%ld".printf(video.Duration));
			}
			else if (st is AudioStream){
				var audio = st as AudioStream;
				if ((audio.StreamSize == 0) && (audio.Duration > 0) && (audio.BitRate > 0)){
					audio.StreamSize = (int64) ((audio.Duration / 1000.0) * audio.BitRate * 1000.0 / 8);
				}
			}
		}

	}

	public void query_mediainfo_formatted(){
		
		InfoTextFormatted = get_mediainfo (Path, false);

		string ext = Extension.down();
		if ((ext == ".jpg")||(ext == ".jpeg")||(ext == ".tiff")||(ext == ".pdf")||(ext == ".png")){
			string exif = get_exif_info(Path);
			InfoTextFormatted += "\nExif\n%s".printf(exif);
		}
	}

	public static string get_mediainfo (string filePath, bool getRawText){

		/* Returns the multimedia properties of an audio/video file using MediaInfo */

		string std_out, std_err;

		string cmd = "mediainfo%s '%s'".printf((getRawText ? " --Language=raw" : ""), escape_single_quote(filePath));
		log_debug(cmd);
		exec_sync(cmd, out std_out, out std_err);

		return std_out;
	}

	public static string get_exif_info (string filePath){

		/* Returns the multimedia properties of an audio/video file using MediaInfo */

		string std_out, std_err;

		string cmd = "exiftool '%s'".printf(escape_single_quote(filePath));
		log_debug(cmd);
		exec_sync(cmd, out std_out, out std_err);

		return std_out;
	}
	
	public long parse_duration(string txt){
		long dur = 0;
		foreach(string p in txt.split(" ")){
			string part = p.strip().down();
			if (part.contains ("h") || part.contains ("hr"))
				dur += long.parse(part.replace ("hr","").replace ("h","")) * 60 * 60 * 1000;
			else if (part.contains ("mn") || part.contains ("min"))
				dur += long.parse(part.replace ("min","").replace ("mn","")) * 60 * 1000;
			else if (part.contains ("ms"))
				dur += long.parse(part.replace ("ms",""));
			else if (part.contains ("s"))
				dur += long.parse(part.replace ("s","")) * 1000;
		}
		return dur;
	}
	
	public void prepare (string baseTempDir){
		TempDirectory = baseTempDir + "/" + timestamp_for_path() + " - " + Title;
		LogFile = TempDirectory + "/" + "log.txt";
		TempScriptFile = TempDirectory + "/convert.sh";
		OutputFilePath = "";
		dir_create (TempDirectory);

		//initialize output frame count
		if (HasVideo && Duration > 0 && SourceFrameRate > 1) {
			OutputFrameCount = (long) ((Duration / 1000.0) * (SourceFrameRate));
		}
		else{
			OutputFrameCount = 0;
		}
	}

	public void generate_thumbnail(){
		
		if (HasVideo){
			
			ThumbnailImagePath = get_temp_file_path() + ".png";
			string std_out, std_err;
			
			exec_sync("%s -ss 1 -i \"%s\" -y -f image2 -vframes 1 -r 1 -s %dx%d \"%s\"".printf(
				"ffmpeg",Path,ThumbnailWidth,ThumbnailHeight,ThumbnailImagePath), out std_out, out std_err);

			//log_msg(std_err);
		}
		else{
			ThumbnailImagePath = "/usr/share/%s/images/%s".printf(AppShortName, "audio.svg");
		}
	}

	//properties ---------------------------

	public bool HasVideo{
		get {
			bool has = false;
			foreach(MediaStream stream in video_list){
				if (stream.IsSelected){
					has = true;
					break;
				}
			}
			return has;
		}
	}

	public bool HasAudio{
		get {
			bool has = false;
			foreach(MediaStream stream in audio_list){
				if (stream.IsSelected){
					has = true;
					break;
				}
			}
			return has;
		}
	}

	public bool HasSubs{
		get {
			bool has = false;
			foreach(MediaStream stream in text_list){
				if (stream.IsSelected){
					has = true;
					break;
				}
			}
			return has;
		}
	}
	
	//cropping --------------------
	
	public bool crop_detect(){
		
		if (HasVideo == false) {
			AutoCropError = true;
			return false;
		}

		string params = get_file_crop_params(Path);
		string[] arr = params.split (":");

		int CropW = 0;
		int CropH = 0;
		if (arr.length == 4){
			CropW = int.parse (arr[0]);
			CropH = int.parse (arr[1]);
			CropL = int.parse (arr[2]);
			CropT = int.parse (arr[3]);
		}

		CropR = SourceWidth - CropW - CropL;
		CropB = SourceHeight - CropH - CropT;

		log_debug("Detected: ffmpeg: %d,%d,%d,%d".printf(CropL,CropR,CropT,CropB));

		if ((CropW == 0) && (CropH == 0)){
			AutoCropError = true;
			return false;
		}
		else
			return true;
	}

	public bool crop_enabled(){
		if ((CropL == 0) && (CropR == 0) && (CropT == 0) && (CropB == 0))
			return false;
		else
			return true;
	}

	public void crop_reset(){
		CropL = 0;
		CropT = 0;
		CropR = 0;
		CropB = 0;
	}

	public string crop_values_info(){
		if (crop_enabled())
			return "%i:%i:%i:%i".printf(CropL,CropT,CropR,CropB);
		else if (AutoCropError)
			return _("N/A");
		else
			return "";
	}

	public string crop_values_libav(){
		if (crop_enabled()){
			int w = SourceWidth - CropL - CropR;
			int h = SourceHeight - CropT - CropB;
			int x = CropL;
			int y = CropT;
			return "%i:%i:%i:%i".printf(w,h,x,y);
		}
		else{
			return "iw:ih:0:0";
		}
	}

	public string crop_values_x264(){
		if (crop_enabled())
			return "%i,%i,%i,%i".printf(CropL,CropT,CropR,CropB);
		else
			return "0,0,0,0";
	}
}

public class MediaClip : GLib.Object{
	public double StartPos = 0.0;
	public double EndPos = 0.0;

	public double Duration(){
		return (EndPos - StartPos);
	}
}

public abstract class MediaStream : GLib.Object{
	
    public MediaStreamType Type = MediaStreamType.UNKNOWN;
    public int Index = -1;
    public int TypeIndex = -1;
    public string Description = "";
	public bool IsSelected = true;
	
	internal MediaStream(MediaStreamType _type){
		Type = _type;
	}
	
    public enum MediaStreamType{
		UNKNOWN,
		GENERAL,
		AUDIO,
		VIDEO,
		TEXT
	}

	public abstract string description{
        owned get;
    }
}

public class GeneralStream : MediaStream {
	public string Format = "";

	public GeneralStream(){
		base(MediaStreamType.GENERAL);
	}

	public override string description{
        owned get {
			return "%s".printf(Format);
		}
    }
}

public class VideoStream : MediaStream {
	public string Format = "";
	public int Width = 0;
	public int Height = 0;
	public double FrameRate = 0;
	public int BitRate = 0;
	public int64 StreamSize = 0;
	public long Duration = 0;
	
	public VideoStream(){
		base(MediaStreamType.VIDEO);
	}

	public override string description{
        owned get {
			string s = "";
			if (Format.length > 0){
				s += "%s".printf(Format);
			}
			if ((Width > 0) && (Height > 0)){
				if (s.length > 0){
					s += ", ";
				}
				s += "%dx%d".printf(Width, Height);
			}
			if (FrameRate > 0){
				if (s.length > 0){
					s += ", ";
				}
				s += "%.3f fps".printf(FrameRate);
			}
			if (BitRate > 0){
				if (s.length > 0){
					s += ", ";
				}
				s += "%d k".printf(BitRate);
			}
			return s;
		}
    }
}

public class AudioStream : MediaStream {
	public string Format = "";
	public string LangCode = "";
	public int Channels = 0;
	public int SampleRate = 0;
	public int BitRate = 0;
	public int64 StreamSize = 0;
	public long Duration = 0;
	
	public AudioStream(){
		base(MediaStreamType.AUDIO);
	}

	public override string description{
        owned get {
			string s = "";
			if (Format.length > 0){
				s += "%s".printf(Format);
			}
			if (Channels > 0){
				if (s.length > 0){
					s += ", ";
				}
				s += "%d ch".printf(Channels);
			}
			if (SampleRate > 0){
				if (s.length > 0){
					s += ", ";
				}
				s += "%d hz".printf(SampleRate);
			}
			if (BitRate > 0){
				if (s.length > 0){
					s += ", ";
				}
				s += "%d k".printf(BitRate);
			}
			if (LangCode.length > 0){
				if (s.length > 0){
					s += " ";
				}
				s += "(%s)".printf(LangCode);
			}
			return s;
		}
    }
}

public class TextStream : MediaStream {
	public string Format = "";
	public string LangCode = "";
	public string Title = "";
	public int64 StreamSize = 0;
	
	public string SubName = "";
	public string SubExt = "";
	public string SubFile = "";
	public string CharacterEncoding = "";
	
	public TextStream(){
		base(MediaStreamType.TEXT);
	}

	public override string description{
        owned get {
			string s = "";

			if (IsExternal){
				s += "%s".printf("External");
				if (CharacterEncoding.length > 0){
					s += ", %s".printf(CharacterEncoding);
				}
				if (Title.length > 0){
					if (s.length > 0){
						s += ", ";
					}
					s += "%s".printf(Title);
				}
				if (LangCode.length > 0){
					if (s.length > 0){
						s += " ";
					}
					s += "(%s)".printf(LangCode);
				}
				s += ", '%s'".printf(SubName);
			}	
			else{
				if (Format.length > 0){
					s += "%s".printf(Format);
				}
				if (Title.length > 0){
					if (s.length > 0){
						s += ", ";
					}
					s += "%s".printf(Title);
				}
				if (LangCode.length > 0){
					if (s.length > 0){
						s += " ";
					}
					s += "(%s)".printf(LangCode);
				}
			}
			
			return s;
		}
    }

	public bool IsExternal{
		get {
			return (SubFile.length > 0);
		}
	}

	public void get_character_encoding(){
		string stdout, stderr;
		exec_sync("LC_ALL=C file -i \"%s\"".printf(SubFile), out stdout, out stderr);
		//log_msg("LC_ALL=C file -i \"%s\"".printf(SubFile));
		//log_msg("out=%s".printf(stdout));
		foreach(string line in stdout.split("\n")){
			if (line.contains("charset=")){
				CharacterEncoding = line.split("charset=")[1].up();
				break;
			}
		}
	}
}

public class LanguageCodes : GLib.Object{
	public static Gee.HashMap<string,string> map_2_to_3;
	public static Gee.HashMap<string,string> map_3_to_2;
	public static Gee.HashMap<string,string> map_2_to_Name;
	public static Gee.HashMap<string,string> map_3_to_Name;

	public static Gee.ArrayList<Language> lang_list;
	
	private static void initialize(){
		lang_list = new Gee.ArrayList<Language>();
		map_2_to_3 = new Gee.HashMap<string,string>();
		map_3_to_2 = new Gee.HashMap<string,string>();
		map_2_to_Name = new Gee.HashMap<string,string>();
		map_3_to_Name = new Gee.HashMap<string,string>();
	}
	
	public class Language : GLib.Object{
		public string Name = "";
		public string Code2 = "";
		public string Code3 = "";

		public Language(string _Name, string _Code2, string _Code3){
			Name = _Name;
			Code2 = _Code2;
			Code3 = _Code3;

			map_2_to_3[Code2] = Code3;
			map_3_to_2[Code3] = Code2;
			map_2_to_Name[Code2] = Name;
			map_3_to_Name[Code3] = Name;
			lang_list.add(this);
		}
	}

	public static void build_maps(){
		initialize();
		
		string stdout, stderr;
		exec_sync("LC_ALL=C mkvmerge --list-languages", out stdout, out stderr);
		foreach(string line in stdout.split("\n")){
			string[] parts = line.split("|");
			if (parts.length == 3){
				string name = parts[0].split(";")[0].split("(")[0].strip();
				string code3 = parts[1].strip().down();
				string code2 = parts[2].strip().down();
				new Language(name,code2,code3);
			}
		}

		//sort languages by name
		CompareDataFunc<Language> func = (a, b) => {
			return strcmp(a.Name, b.Name);
		};
		lang_list.sort((owned)func);
	}
}


