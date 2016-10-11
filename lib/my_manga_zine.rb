require 'mangdown'
require_relative '../../my_manga/db/environment'

module MyManga
  module Zine
    def self.publish
      zine = zine_content
      zine.each do |chapter|
        chapter.to_md.download_to(Dir.pwd + '/zine')
      end

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
    end
  end
end
