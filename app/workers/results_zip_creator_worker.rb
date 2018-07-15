class ResultsZipCreatorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(results_id, type)
    begin
      results = ResultsZip.find results_id
      prepare results
      process(results, type)
    rescue Exception => e
      on_failing results
      raise e
    end
  end

  private

  def prepare(results)
    filename = results.query.gsub(/ +/, "_") + ".zip"

    results.update_attributes! filename: filename, worker_id: self.jid, status: ResultsZip.status_of(:processing)
    ResultsZip.destroy_olds!
    results
  end

  def process(results, type)
    readmes = GithubConsumer.public_send(:"get_#{type}", results.query)
    binary = ZipBinaryCreator.create_zip_for(readmes)

    results.finish! BSON::Binary.new(binary)
  end

  def on_failing(results)
    results && results.update_attributes!(status: ResultsZip.status_of(:failed))
  end
end