require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require 'rainbow/refinement'
using Rainbow

require 'digest'

TMP_DIR     = File.expand_path FileUtils.mkdir_p("tmp/")[0]
FRAMES_DIR  = File.expand_path FileUtils.mkdir_p(File.join(TMP_DIR, 'frames'))[0]
DIGESTS_DIR = File.expand_path FileUtils.mkdir_p(File.join(TMP_DIR, 'digests'))[0]
OUT_DIR     = File.expand_path FileUtils.mkdir_p("out/")[0]
INPUT_FPS   = 30

def to_out_image_name(image, frame_nr, out_prefix, out_suffix)
  File.expand_path([
    out_prefix, 
    '-', 
    File.basename(image, '.*'), 
    '-', 
    out_suffix, 
    '-',
    frame_nr.to_s.rjust(3, '0'),
    File.extname(image)].join
  )
end

def when_things_changed(input_file_names:, cmd:, current_out_file_name:)
  cmd_digest = cmd
  current_cmd_file_name = File.join(DIGESTS_DIR, File.basename(current_out_file_name) + ".cmd_digest")
  cmd_changed = !(File.exists?(current_cmd_file_name) && File.read(current_cmd_file_name) == cmd_digest)
  
  input_digest = input_file_names.map { |input_file_name| Digest::MD5.hexdigest(File.read(input_file_name)) }.join("\n") 
  current_input_digest_file_name = File.join(DIGESTS_DIR, File.basename(current_out_file_name) + ".input_digest")
  image_changed = !(File.exists?(current_input_digest_file_name) && File.read(current_input_digest_file_name) == input_digest) 
 
  yield if cmd_changed || image_changed

  File.write(current_cmd_file_name, cmd_digest)
  File.write(current_input_digest_file_name, input_digest)
  
 end

def to_frames(image:, out_suffix:, nr_frames: 1, duration: nil, out_prefix: '00', keep_existing: true, reverse: false)
  dir = FRAMES_DIR 

  absolute_image_path = File.expand_path(image)
  nr_frames = (duration * INPUT_FPS).round if duration
  frame_files = Concurrent::Array.new
  spinner = TTY::Spinner.new(
    "[:spinner] Operation: #{out_suffix.cyan} | Nr. Frames: #{nr_frames.to_s.rjust(3).yellow} | File: #{File.basename(image).yellow}", 
    format: :pulse_2,
    success_mark: '✓'.green,
    hide_cursor: true
  )
  spinner.auto_spin


  out_images = Dir.chdir(dir) do |_dir|
    Parallel.map((nr_frames).times, in_processes: 16) do |frame_nr|
      current_out_image_name = to_out_image_name(image, frame_nr, out_prefix, out_suffix) 
      frame_files << current_out_image_name

      frame_nr = nr_frames - frame_nr - 1 if reverse
      cmd = yield frame_nr, current_out_image_name, nr_frames, absolute_image_path
      
      when_things_changed(input_file_names: [absolute_image_path], cmd: cmd, current_out_file_name: current_out_image_name) do
        `#{cmd}`
      end

      current_out_image_name
    end
  end
  spinner.success
  out_images
end

def tilt_image_to_frames(image:, to_angle: 0, nr_frames: 1, duration: nil, keep_existing: true, out_prefix: '', transparent: true, reverse: false)
  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    duration: duration,
    out_suffix: 'tilt', 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name, nr_frames, absolute_image_path|
    current_tilt_value = to_angle.to_f / nr_frames.to_f * (frame_nr.to_f + 1)
    bgcolor = transparent ? 'none' : 'white -alpha remove -alpha off'
    
    "3Drotate tilt=#{current_tilt_value} bgcolor='#{bgcolor}' '#{absolute_image_path}' '#{current_out_image_name}'"
  end
end

def lift_image_to_frames(image:, height:, background_image: nil, background_fade: false, nr_frames: 1, duration: nil, keep_existing: true, out_suffix: 'lift', out_prefix: '', reverse: false)
  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    duration: duration,
    out_suffix: out_suffix, 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name, nr_frames, absolute_image_path|
    current_height = height.to_f / nr_frames.to_f * (frame_nr.to_f + 1)
    
    background_image_arg = if background_image
      "'#{background_image}'" + if background_fade
        percent = (frame_nr.to_f / nr_frames.to_f * 100).to_i
        " -fill white -colorize #{percent}%"
      else
        ''
      end
    else
      " -background white"
    end

    "convert #{background_image_arg} -page +0-#{current_height}% '#{absolute_image_path}' -flatten '#{current_out_image_name}'"
  end
end

def fade_over(image:, overlay_image: nil, nr_frames: 1, duration: nil, keep_existing: true, out_suffix: 'fade', out_prefix: '', transparent: true, reverse: false)
  absolute_overlay_image_path = File.expand_path(overlay_image)

  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    duration: duration,
    out_suffix: out_suffix, 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name, nr_frames, absolute_image_path|
    percent = (frame_nr.to_f / nr_frames.to_f)
    
    bgcolor = if transparent
      'none'
    else
      'white -alpha remove -alpha off'
    end
    
    "convert '#{absolute_overlay_image_path}' -background white -alpha remove -alpha off \\( #{absolute_image_path} -alpha set -channel A -evaluate multiply #{percent} +channel \\) -compose over -composite '#{current_out_image_name}'"
  end
end


def render_ffmpeg(frames:, name:, format: nil)
  out_filename = File.join(OUT_DIR, "#{name}.#{format}")

  spinner = TTY::Spinner.new(
    "[:spinner] Rendering: #{out_filename.green} | Nr. Frames: #{frames.count.to_s.rjust(3).yellow} -> Duration: ~#{(frames.count.to_f / INPUT_FPS.to_f).round}s", 
    format: :dots,
    success_mark: '✓'.green,
    hide_cursor: true
  )
  spinner.auto_spin

  render_sequence_filename = File.join(TMP_DIR, 'render_sequence.ffmpeg.txt')
  File.write(render_sequence_filename, frames.map { |f| "file '#{f}'\nduration #{1/INPUT_FPS.to_f}" }.join("\n"))

  ffmpeg_args = "-y -hide_banner -loglevel error"

  yield out_filename, render_sequence_filename, ffmpeg_args

  spinner.success
end

def render_animation_mp4(frames:, name:, width:)
  render_ffmpeg(frames: frames, name: name, format: "mp4") do |out_filename, render_sequence_filename, ffmpeg_args|
    cmd = "ffmpeg #{ffmpeg_args} -f concat -safe 0 -r #{INPUT_FPS} -i #{render_sequence_filename} -vf scale=#{width}:-1 #{out_filename}"
    when_things_changed(input_file_names: frames, cmd: cmd, current_out_file_name: out_filename) do
      `#{cmd}`
    end
  end
end

def render_animation_gif(frames:, name:, width:, fps:15)
  render_ffmpeg(frames: frames, name: name, format: "gif") do |out_filename, render_sequence_filename, ffmpeg_args|
    ## https://medium.com/@Peter_UXer/small-sized-and-beautiful-gifs-with-ffmpeg-25c5082ed733
    tmp_file = File.join(TMP_DIR, "/#{name}_tmp.gif")

  
    cmd = "ffmpeg #{ffmpeg_args} -f concat -safe 0 -r #{INPUT_FPS} -i #{render_sequence_filename} -filter_complex '[0:v] fps=#{fps},scale=w=#{width}:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1' #{tmp_file}"
    when_things_changed(input_file_names: frames, cmd: cmd, current_out_file_name: tmp_file) do
      `#{cmd}`
    end
   
    cmd = "gifsicle --colors 256 -O3 #{tmp_file} -o #{out_filename}"
    when_things_changed(input_file_names: frames, cmd: cmd, current_out_file_name: out_filename) do
      `#{cmd}`
    end
  end
end


tilt_angle  = 70
lift_height = 250

overview_image         = 'layers/0_system.drawio.png'
framework_image        = 'layers/1_framework.drawio.png'
framework_system_image = 'layers/2_framework_system.drawio.png'

overview_frames = tilt_image_to_frames(
  image: overview_image, 
  to_angle: tilt_angle, 
  duration: 2,
  out_prefix: '01', 
  transparent: false
)

framework_frames = tilt_image_to_frames(
  image: framework_image, 
  to_angle: tilt_angle, 
  nr_frames: 1,
  out_prefix: '000',
  reverse: true
)

framework_lift_frames = lift_image_to_frames(
  image: framework_frames[0], 
  background_image: overview_frames[-1],
  background_fade: true,
  height: lift_height, 
  duration: 1,
  out_prefix: '02'
)

framework_lift_frames_reverse = lift_image_to_frames(
  image: framework_frames[0], 
  height: lift_height,
  duration: 1,
  out_suffix: 'lift', 
  out_prefix: '03', 
  reverse: true
)

framework_tilt_frames_reverse = tilt_image_to_frames(
  image: framework_image, 
  to_angle: tilt_angle,
  duration: 1,
  out_prefix: '04', 
  transparent: false, 
  reverse: true
)

framework_system_fade_over_frames = fade_over(
  image: framework_system_image,
  overlay_image: framework_image,
  duration: 1,
  out_prefix: '05', 
  transparent: false
)


render_frames =  []
render_frames += overview_frames
render_frames += Array.new(5, overview_frames[-1]) 
render_frames += framework_lift_frames
render_frames += Array.new(5, framework_lift_frames[-1])
render_frames += framework_lift_frames_reverse
render_frames += framework_tilt_frames_reverse
render_frames += framework_system_fade_over_frames
render_frames += Array.new(60, framework_system_fade_over_frames[-1])

render_animation_mp4(
  frames: render_frames, 
  name: 'animation',
  width: 1920
)

render_animation_mp4(
  frames: overview_frames,
  name: '1_overview',
  width: 1920,
)

render_animation_mp4(
  frames: framework_lift_frames,
  name: '2_framework_lift',
  width: 1920,
)

render_animation_mp4(
  frames: framework_lift_frames_reverse,
  name: '3_framework_lift_reverse',
  width: 1920,
)

render_animation_mp4(
  frames: framework_tilt_frames_reverse,
  name: '4_framework_tilt_reverse',
  width: 1920,
)

render_animation_mp4(
  frames: framework_system_fade_over_frames,
  name: '5_framework_system_fade_over',
  width: 1920,
)