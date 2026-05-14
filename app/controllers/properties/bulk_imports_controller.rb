module Properties
  class BulkImportsController < ApplicationController
    def new
      @batch_token = nil
    end

    def create
      raw_input = bulk_input_text

      if raw_input.strip.empty?
        @batch_token = nil
        render :new, status: :ok
        return
      end

      @batch_token = SecureRandom.hex(8)
      PropertyImportJob.perform_later(
        user_id: current_user.id,
        batch_token: @batch_token,
        raw_input: raw_input
      )
      render :new, status: :accepted
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
