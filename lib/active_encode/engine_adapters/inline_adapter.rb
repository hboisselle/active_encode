require 'open3'

module ActiveEncode
  module EngineAdapters
    class InlineAdapter
      include Open3

      class_attribute :encodes, instance_accessor: false, instance_predicate: false
      class_attribute :active_encodes, instance_accessor: false, instance_predicate: false
      InlineAdapter.encodes ||= {}
      InlineAdapter.active_encodes ||= {}

      FFMPEG_PATH = "/usr/local/ffmpeg-20130201/bin/ffmpeg"

      def create(encode)
        encode.id = SecureRandom.uuid
        self.class.encodes[encode.id] = encode
        #start encode
        extension = encode.options.delete(:extension)
        transcode(encode.input, encode.options, encode.options.delete(:output_file) || output_file(encode, extension))
        active_encode[encode.id] = process_info
        #TODO error handling!
        encode.state = :running
        encode
      end

      def find(id, opts = {})
        self.class.encodes[id]
        #TODO fill in information from the ffmpeg command
        #TODO CLOSE stdout/stderr when processing finished!
      end

      def list(*filters)
        raise NotImplementedError
      end

      def cancel(encode)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.state = :cancelled
        #cancel encode
        self.class.active_encodes[encode.id][:thread].kill
        inline_encode
      end

      def purge(encode)
        self.class.encodes.delete encode.id
      end

      def remove_output(encode, output_id)
        inline_encode = self.class.encodes[encode.id]
        return if inline_encode.nil?
        inline_encode.output.delete(inline_encode.output.find {|o| o[:id] == output_id})
      end

      private
      def output_file(encode, extension="mp4")
        File.basename(encode.input).sub(File.extname(encode.input), '') + "." + extension
      end

      def transcode(path, options, out)
        inopts = options.fetch(:input_options,[]).collect{|k,v| "-#{k} #{v}"}.join(" ")
        inopts ||= "-y"
        outopts = options.fetch(:output_options,[]).collect{|k,v| "-#{k} #{v}"}.join(" ")
        outopts ||= options
        execute "#{FFMPEG_PATH} #{inopts} -i \"#{path}\" #{outopts} #{out}"
      end

      def execute(command)
        stdin, stdout, stderr, wait_thr = popen3(command)
        stdin.close
        {out: stdout, err: stderr, thread: wait_thr}
      end
    end
  end
end
