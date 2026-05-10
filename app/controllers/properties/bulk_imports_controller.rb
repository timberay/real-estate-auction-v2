module Properties
  class BulkImportsController < ApplicationController
    def new
      @result = nil
    end

    def create
      raw_input = bulk_input_text
      @result = Properties::BulkImportService.call(user: current_user, raw_input: raw_input)
      render :new, status: (@result.failed.any? ? :unprocessable_entity : :ok)
    end

    private

    def bulk_input_text
      if (file = params[:csv_file]).present?
        file.read.force_encoding("UTF-8").delete_prefix("\xEF\xBB\xBF")
      else
        params[:bulk_input].to_s
      end
    end
  end
end
