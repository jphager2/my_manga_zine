require 'mangdown'
require_relative '../../my_manga/db/environment'
require_relative '../../my_manga/lib/my_manga'

module MyManga
  module Zine
    LOG_FILE = File.expand_path('../log/my_manga_zine.log', __dir__).freeze

    def self.publish(name, manga)
      Dir.mkdir('tmp') unless Dir.exist?('tmp')

      zine = zine_content(manga)
      serialized_name = []
      zine.each do |chapter|
        serialized_name << chapter.id
        chapter.to_md.download_to(Dir.pwd + '/tmp')
        MyManga.read!(chapter.manga, [chapter.number]) if read_on_publish?
      end

      serialized_name = serialized_name.join.to_i.to_s(32)

      dir = File.join(MyManga.download_dir, "#{name}-#{serialized_name}")

      cbz(dir)

      utils.rm_r('tmp') if clean_up_files?

      # Create an epub from the files (use rpub)
      # Need to get the styles right
      # (look at viewport, image dimensions, etc.)
    end

    class << self
      def debug?
        ENV['DEBUG'] || $DEBUG
      end

      private

      def zine_content(manga)
        chapter_count = 2 * manga.length
        chapters = Chapter
                   .unread
                   .where(manga_id: manga.map(&:id))
                   .order(:number)
                   .group_by(&:manga)
                   .values
                   .sort_by(&:length)
                   .reverse

        return if chapters.empty?

        zine = chapters.first.zip(*chapters.drop(1)).flatten.compact
        zine.first(chapter_count).sort_by do |chapter|
          [chapter.manga_id, chapter.number]
        end
      end

      def cbz(dir)
        pages = Dir['tmp/**/*.*']

        Dir.mkdir(dir) unless Dir.exist?(dir)

        pages.each do |page|
          filename = File.basename(page)
          utils.cp(page, File.join(dir, filename))
        end

        Mangdown::CBZ.one(dir, false)

        utils.rm_r(dir) if clean_up_files?
      end

      def read_on_publish?
        ENV['MY_MANGA_ZINE_NO_READ'].nil? && !debug?
      end

      def clean_up_files?
        ENV['MY_MANGA_ZINE_NO_CLEAN_UP'].nil? && !debug?
      end

      def utils
        debug? ? FileUtils::Verbose : FileUtils
      end
    end
  end
end

unless MyManga::Zine.debug?
  Mangdown.configure_logger(file: MyManga::Zine::LOG_FILE)
end
