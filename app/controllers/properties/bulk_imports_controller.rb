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
      # Brief wait gives the browser time to establish the Turbo Stream
      # subscription before the job starts broadcasting. Without it, very
      # fast jobs (e.g. all-unknown-court input that fails without HTTP)
      # finish before the subscriber connects and the user sees only the
      # placeholder.
      PropertyImportJob.set(wait: 0.5.seconds).perform_later(
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
