function imdb = refNet1_imagenet_setup_data(varargin)
% CNN_IMAGENET_SETUP_DATA  Initialize ImageNet ILSVRC CLS-LOC challenge data
%
%    Jake's version
%
%    In order to use the ILSVRC data with these scripts, please
%    unpack it as follows. Create a root folder <DATA>, by default
%
%    data/imagenet12
%
%    (note that this can be a simlink). Use the 'dataDir' option to
%    specify a different path.
%
%    Within this folder, create the following hierarchy:
%
%    <DATA>/images/train/ : content of ILSVRC2012_img_train.tar
%    <DATA>/images/val/ : content of ILSVRC2012_img_val.tar
%    <DATA>/images/test/ : content of ILSVRC2012_img_test.tar
%    <DATA>/ILSVRC2012_devkit : content of ILSVRC2012_devkit.tar
%
%    In order to speedup training and testing, it may be a good idea
%    to preprocess the images to have a fixed size (e.g. 256 pixels
%    high) and/or to store the images in RAM disk (provided that
%    sufficient RAM is available). Reading images off disk with a
%    sufficient speed is crucial for fast training.

opts = vl_argparse(opts, varargin) ;

% -------------------------------------------------------------------------
%                                                  Load categories metadata
% -------------------------------------------------------------------------

d = dir(fullfile(opts.dataDir, 'objects')) ;
d = [d dir(fullfile(opts.dataDir, 'images'))] ;
if numel(d) == 0
    error('Make sure that both data/images/... and data/objects/... exist');
end

categories = readtable(fullfile(fileparts(mfilename('fullpath')), ...
  'development_kit', 'data', 'categories.txt'), 'Delimiter',' ');

cat_cell = table2cell(categories);

% Note that the position of a category in the cell array is it's label
% number
cats = {cat_cell(1:height(categories))} ; % categories but not mapped to numbers
% descrs = {meta.synsets(1:1000).words} ; %TODO put descrs, if we have them, here

imdb.classes.name = cats ;
% imdb.classes.description = descrs ;
imdb.imageDirs = getAllFiles(opts.dataDir); % This should be the full list of all image pathnames

% -------------------------------------------------------------------------
%                                                           Training images
% -------------------------------------------------------------------------

fprintf('searching training images ...\n') ;
names = {} ;
labels = {} ;
% maybe want to iterate a level down
for d = dir(fullfile(opts.dataDir, 'images', 'train', 'n*'))'
  [~,lab] = ismember(d.name, cats) ;
  ims = dir(fullfile(opts.dataDir, 'images', 'train', d.name, '*.JPG')) ;
  names{end+1} = strcat([d.name, filesep], {ims.name}) ;
  labels{end+1} = ones(1, numel(ims)) * lab ;
  fprintf('.') ;
  if mod(numel(names), 50) == 0, fprintf('\n') ; end
  %fprintf('found %s with %d images\n', d.name, numel(ims)) ;
end
names = horzcat(names{:}) ;
labels = horzcat(labels{:}) ;

if numel(names) ~= 100000
  warning('Found %d training images instead of 100,000. Dropping training set.', numel(names)) ;
  names = {} ;
  labels =[] ;
end

names = strcat(['train' filesep], names) ;

imdb.images.id = 1:numel(names) ;
imdb.images.name = names ;
imdb.images.set = ones(1, numel(names)) ;
imdb.images.label = labels ;

% -------------------------------------------------------------------------
%                                                         Validation images
% -------------------------------------------------------------------------

ims = dir(fullfile(opts.dataDir, 'images', 'val', '*.JPG')) ;
names = sort({ims.name}) ;
labels = textread(valLabelsPath, '%d') ;

if numel(ims) ~= 10e3
  warning('Found %d instead of 10,000 validation images. Dropping validation set.', numel(ims))
  names = {} ;
  labels =[] ;
else
  if ~isempty(valBlacklistPath)
    black = textread(valBlacklistPath, '%d') ;
    fprintf('blacklisting %d validation images\n', numel(black)) ;
    keep = setdiff(1:numel(names), black) ;
    names = names(keep) ;
    labels = labels(keep) ;
  end
end

names = strcat(['val' filesep], names) ;

imdb.images.id = horzcat(imdb.images.id, (1:numel(names)) + 1e7 - 1) ;
imdb.images.name = horzcat(imdb.images.name, names) ;
imdb.images.set = horzcat(imdb.images.set, 2*ones(1,numel(names))) ;
imdb.images.label = horzcat(imdb.images.label, labels') ;

% -------------------------------------------------------------------------
%                                                               Test images
% -------------------------------------------------------------------------

ims = dir(fullfile(opts.dataDir, 'images', 'test', '*.JPG')) ;
names = sort({ims.name}) ;
labels = zeros(1, numel(names)) ;

if numel(labels) ~= 10e3
  warning('Found %d instead of 10,000 test images', numel(labels))
end

names = strcat(['test' filesep], names) ;

imdb.images.id = horzcat(imdb.images.id, (1:numel(names)) + 2e7 - 1) ;
imdb.images.name = horzcat(imdb.images.name, names) ;
imdb.images.set = horzcat(imdb.images.set, 3*ones(1,numel(names))) ;
imdb.images.label = horzcat(imdb.images.label, labels) ;

end

% Searches recursively through all subdirectories of a given directory, 
% collecting a list of all file paths it finds
function fileList = getAllFiles(dirName)

  dirData = dir(dirName);      %# Get the data for the current directory
  dirIndex = [dirData.isdir];  %# Find the index for directories
  fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files
  if ~isempty(fileList)
    fileList = cellfun(@(x) fullfile(dirName,x),...  %# Prepend path to files
                       fileList,'UniformOutput',false);
  end
  subDirs = {dirData(dirIndex).name};  %# Get a list of the subdirectories
  validIndex = ~ismember(subDirs,{'.','..'});  %# Find index of subdirectories
                                               %#   that are not '.' or '..'
  for iDir = find(validIndex)                  %# Loop over valid subdirectories
    nextDir = fullfile(dirName,subDirs{iDir});    %# Get the subdirectory path
    fileList = [fileList; getAllFiles(nextDir)];  %# Recursively call getAllFiles
  end
end
