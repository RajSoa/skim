require 'rake-pipeline/middleware'

use Rake::Pipeline::Middleware, 'Assetfile'
run BlagApp
