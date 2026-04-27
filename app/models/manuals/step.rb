# frozen_string_literal: true

module Manuals
  Step = Data.define(:number, :key, :status, :detail) do
    def done? = status == :done
    def in_progress? = status == :in_progress
    def pending? = status == :pending
    def none? = status == :none
  end
end
