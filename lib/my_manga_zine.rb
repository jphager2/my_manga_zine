require 'mangdown'
require_relative '../../my_manga/db/environment'
require_relative '../../my_manga/lib/my_manga'

module MyManga
  module Zine
    def self.publish(name)
      Dir.mkdir('tmp') unless Dir.exist?('tmp')

      zine = zine_content
      serialized_name = []
      zine.each do |chapter|
        serialized_name << chapter.id
        chapter.to_md.download_to(Dir.pwd + '/tmp')
        MyManga.read!(chapter.manga, [chapter.number]) if read_on_publish?
      end

      serialized_name = serialized_name.join.to_i.to_s(32)

      cbz("#{name}-#{serialized_name}")

      utils.rm_r('tmp') if clean_up_files?

      # Create an epub from the files (use rpub)
      # Need to get the styles right
      # (look at viewport, image dimensions, etc.)
    end

    class << self

      private

      def zine_content
        manga_count = Manga.count
        chapter_count = 2 * manga_count
        manga = Chapter
                .unread
                .where(manga_id: Manga.ids)
                .order(:number)
                .group_by(&:manga)

        chapters = manga.values
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
          utils.cp(page, File.join(MyManga.download_dir, dir, filename))
        end

        Mangdown::CBZ.one(dir)

        utils.rm_r(dir) if clean_up_files?
      end

      def read_on_publish?
        ENV['MY_MANGA_ZINE_NO_READ'].nil? && !debug?
      end

      def clean_up_files?
        ENV['MY_MANGA_ZINE_CLEAN_UP'].nil? && !debug?
      end

      def debug?
        ENV['DEBUG'] || $DEBUG
      end

      def utils
        debug? ? FileUtils::Verbose : FileUtils
      end
    end
  end
end
