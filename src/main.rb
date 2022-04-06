require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require 'rainbow/refinement'
using Rainbow

TMP_DIR = FileUtils.mkdir_p("tmp/")[0]
FRAMES_DIR = FileUtils.mkdir_p(File.join(TMP_DIR, 'frames'))[0]
OUT_DIR = FileUtils.mkdir_p("out/")[0]


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

def to_frames(image:, out_suffix:, nr_frames: 1, out_prefix: '00', keep_existing: true, reverse: false)
  dir = FRAMES_DIR 

  frame_files = Concurrent::Array.new
  spinner = TTY::Spinner.new(
    "[:spinner] #{File.basename(image).yellow} @ #{out_suffix.cyan}", 
    format: :pulse_2,
    success_mark: '✓'.green,
    hide_cursor: true
  )
  spinner.auto_spin

  out_images = Dir.chdir(dir) do |_dir|
    Parallel.map((nr_frames + 1).times, in_processes: 16) do |frame_nr|
      current_out_image_name = to_out_image_name(image, frame_nr, out_prefix, out_suffix) 
      frame_files << current_out_image_name
      next current_out_image_name if keep_existing && File.exist?(current_out_image_name)

      frame_nr = nr_frames - frame_nr - 1 if reverse
      cmd = yield frame_nr, current_out_image_name
      `#{cmd}`

      current_out_image_name
    end
  end
  spinner.success
  out_images
end

def tilt_image_to_frames(image:, to_angle: 0, nr_frames: 1, keep_existing: true, out_prefix: '', transparent: true, reverse: false)
  absolute_image_path = File.expand_path(image)

  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    out_suffix: 'tilt', 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name|
    current_tilt_value = to_angle.to_f / nr_frames.to_f * (frame_nr.to_f + 1)
    bgcolor = transparent ? 'none' : 'white -alpha remove -alpha off'
    
    "3Drotate tilt=#{current_tilt_value} zoom=1 bgcolor='#{bgcolor}' '#{absolute_image_path}' '#{current_out_image_name}'"
  end
end

def lift_image_to_frames(image:, height:, background_image: nil, background_fade: false, nr_frames: 1, keep_existing: true, out_suffix: 'lift', out_prefix: '', reverse: false)
  absolute_image_path = File.expand_path(image)

  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    out_suffix: out_suffix, 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name|
    current_height = height.to_f / nr_frames.to_f * (frame_nr.to_f + 1)
    
    background_image_arg = if background_image
      "'#{background_image}'" + if background_fade
        percent = (frame_nr.to_f / nr_frames.to_f * 100).to_i
        " -fill white -colorize #{percent}%"
      else
        ''
      end
    else
      ''
    end

    "convert #{background_image_arg} -page +0-#{current_height}% -background white -gravity center '#{absolute_image_path}' -flatten '#{current_out_image_name}'"
  end
end

def fade_over(image:, overlay_image: nil, nr_frames: 1, keep_existing: true, out_suffix: 'fade', out_prefix: '', transparent: true, reverse: false)
  absolute_image_path = File.expand_path(image)
  absolute_overlay_image_path = File.expand_path(overlay_image)

  to_frames(
    image: image, 
    nr_frames: nr_frames, 
    out_suffix: out_suffix, 
    out_prefix: out_prefix,
    keep_existing: keep_existing, 
    reverse: reverse
  ) do |frame_nr, current_out_image_name|
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
    "[:spinner] Rendering: #{out_filename.green}", 
    format: :dots,
    success_mark: '✓'.green,
    hide_cursor: true
  )
  spinner.auto_spin

  render_sequence_filename = File.join(TMP_DIR, 'render_sequence.ffmpeg.txt')
  File.write(render_sequence_filename, frames.map { |f| "file '#{f}'\nduration 0.033" }.join("\n"))

  ffmpeg_args = "-y -hide_banner -loglevel error"

  yield out_filename, render_sequence_filename, ffmpeg_args

  spinner.success


end

def render_animation_mp4(frames:, name:, width: nil)
  render_ffmpeg(frames: frames, name: name, format: "mp4") do |out_filename, render_sequence_filename, ffmpeg_args|
    `ffmpeg #{ffmpeg_args} -f concat -safe 0 -r 30 -i #{render_sequence_filename} -vf scale=#{width}:-1 #{out_filename}`
  end
end

def render_animation_gif(frames:, palette_frame:, name:, width:, fps:15)
  render_ffmpeg(frames: frames, name: name, format: "gif") do |out_filename, render_sequence_filename, ffmpeg_args|
    ## https://medium.com/@Peter_UXer/small-sized-and-beautiful-gifs-with-ffmpeg-25c5082ed733
    cmd = "ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -r 30 -i #{render_sequence_filename} -filter_complex '[0:v] fps=#{fps},scale=w=#{width}:h=-1,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1' #{TMP_DIR}/#{name}.gif"
    `#{cmd}`

    cmd = "gifsicle --colors 256 -O3 #{TMP_DIR}/#{name}.gif -o #{out_filename}"
    `#{cmd}`
  end
end


keep = true
tilt_angle = 70

frame_multiplier = 1

lift_height = 250
up_frames = 15
down_frames = 15

overview_image = 'layers/0_system.drawio.png'
framework_image = 'layers/1_framework.drawio.png'
framework_system_image = 'layers/2_framework_system.drawio.png'

overview_frames = tilt_image_to_frames(
  image: overview_image, 
  to_angle: tilt_angle, 
  nr_frames: 30 * frame_multiplier,
  keep_existing: keep, 
  out_prefix: '01', 
  transparent: false
)

framework_frames = tilt_image_to_frames(
  image: framework_image, 
  to_angle: tilt_angle, 
  nr_frames: 15 * frame_multiplier,
  keep_existing: keep, 
  out_prefix: '000'
)

framework_lift_frames = lift_image_to_frames(
  image: framework_frames[-1], 
  background_image: overview_frames[-1],
  background_fade: true,
  height: lift_height, 
  nr_frames: up_frames * frame_multiplier, 
  keep_existing: keep, 
  out_prefix: '02'
)

framework_lift_frames_reverse = lift_image_to_frames(
  image: framework_frames[-1], 
  height: lift_height,
  nr_frames: down_frames * frame_multiplier, 
  keep_existing: keep, 
  out_suffix: 'lift_reverse', 
  out_prefix: '03', 
  reverse: true
)

framework_tilt_frames_reverse = tilt_image_to_frames(
  image: framework_image, 
  to_angle: tilt_angle,
  nr_frames: 15 * frame_multiplier, 
  keep_existing: keep, 
  out_prefix: '04', 
  transparent: false, 
  reverse: true
)

framework_system_fade_over_frames = fade_over(
  image: framework_system_image,
  overlay_image: framework_image,
  nr_frames: 15 * frame_multiplier, 
  keep_existing: keep, 
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
render_frames += Array.new(15, framework_system_fade_over_frames[-1])

render_animation_mp4(
  frames: render_frames, 
  name: 'animation',
  width: 1920
)

render_animation_gif(
  frames: render_frames,
  palette_frame: render_frames[-1],
  name: 'animation',
  width: 720,
  fps: 30
)

exit
