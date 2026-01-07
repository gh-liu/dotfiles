function! completion#dadbod(findstart, base) abort
  let l:db = get(b:, 'db', get(g:, 'db', ''))
  if l:db == ''
    return a:findstart ? -1 : []
  endif

  let l:db_type = matchstr(l:db, '^\w\+')
  if l:db_type == ''
    return a:findstart ? -1 : []
  endif

  let l:completion_func = 's:' . l:db_type . '_completion'

  if !exists('*' . l:completion_func)
    echohl ErrorMsg
    echom 'completion#dadbod: unsupport: ' . l:db_type
    echohl None
    return a:findstart ? -1 : []
  endif

  return call(l:completion_func, [a:findstart, a:base, l:db])
endfunction


function! s:mongo_completion(findstart, base, db_url) abort
  if a:findstart
    let l:line = getline('.')
    let l:col = col('.')
    let l:before = l:line[:l:col - 1]
    
    if l:before =~# 'db\.\w*$'
      let l:col = match(l:before, '\%(\a\w*\)\?$')
      return l:col != -1 ? l:col : -2
    elseif l:before =~# 'db\.\w\+\.\w*$'
      let l:col = match(l:before, '\%(\a\w*\)\?$')
      return l:col != -1 ? l:col : -2
    endif
    return -1
  else
    let l:len = strlen(a:base)
    let l:line = getline('.')
    let l:col = col('.')
    let l:before = l:line[:l:col - 1]
    
    if l:before =~# 'db\.\w*$'
      return s:mongo_get_collections(a:base, l:len, a:db_url)
    elseif l:before =~# 'db\.\w\+\.\w*$'
      return map(
            \  filter(
            \    copy(s:mongo_collectionMethods),
            \    {k, v -> strpart(v.word, 0, l:len) ==# a:base}
            \  ),
            \  {k, v -> extend(v, {'kind': 'f', 'info': get(v, 'info', ' ')}, "keep")}
            \)
    endif
    return []
  endif
endfunction

function! s:mongo_get_collections(base, len, db_url) abort
  let l:cache_key = 'dadbod_mongo_collections'
  
  if !exists('s:mongo_collection_cache') || get(s:mongo_collection_cache, 'db', '') !=# a:db_url
    let s:mongo_collection_cache = {'db': a:db_url, 'collections': s:mongo_fetch_collections(a:db_url)}
  endif
  
  let l:collections = get(s:mongo_collection_cache, 'collections', [])
  
  return map(
        \  filter(
        \    copy(l:collections),
        \    {k, v -> strpart(v, 0, a:len) ==# a:base}
        \  ),
        \  {k, v -> {'word': v, 'kind': 'v', 'menu': 'collection', 'info': 'MongoDB collection'}}
        \)
endfunction

" 从数据库获取 collection 列表
function! s:mongo_fetch_collections(db_url) abort
  " 尝试使用 dadbod adapter 执行命令获取 collections
  " 如果无法直接获取，返回空列表
  " 用户可以手动添加常用 collections 或通过其他方式获取
  try
    " 这里可以尝试通过 dadbod 的 MongoDB adapter 执行命令
    " 例如: db.getCollectionNames()
    " 如果 dadbod 支持，可以这样调用：
    " let l:result = db#adapter#call(a:db_url, 'execute', 'db.getCollectionNames()')
    " 然后解析结果...
  catch
    " 如果失败，返回空列表
  endtry
  
  " 返回空列表（用户可以通过其他方式添加）
  return []
endfunction

" MongoDB collection 方法列表
let s:mongo_collectionMethods = [
      \ {'word': 'aggregate', 'menu': '( [pipeline], <optional params> )', 'info': 'performs an aggregation on a collection; returns a cursor'},
      \ {'word': 'bulkWrite', 'menu': '( operations, <optional params> )', 'info': 'bulk execute write operations, optional parameters are: w, wtimeout, j'},
      \ {'word': 'convertToCapped', 'menu': '( maxBytes )', 'info': 'calls {convertToCapped: "test", size: maxBytes}} command'},
      \ {'word': 'count', 'menu': '( query = {}, <optional params> )', 'info': 'count the number of documents that matches the query, optional parameters are: limit, skip, hint, maxTimeMS'},
      \ {'word': 'countDocuments', 'menu': '( query = {}, <optional params> )', 'info': 'count the number of documents that matches the query, optional parameters are: limit, skip, hint, maxTimeMS'},
      \ {'word': 'createIndex', 'menu': '( keypattern [,options] )'},
      \ {'word': 'createIndexes', 'menu': '( [keypatterns], <options> )'},
      \ {'word': 'dataSize', 'menu': '()'},
      \ {'word': 'deleteMany', 'menu': '( filter, <optional params> )', 'info': 'delete all matching documents, optional parameters are: w, wtimeout, j'},
      \ {'word': 'deleteOne', 'menu': '( filter, <optional params> )', 'info': 'delete first matching document, optional parameters are: w, wtimeout, j'},
      \ {'word': 'distinct', 'menu': '( key, query, <optional params> )', 'info': 'e.g. db.test.distinct( "x" ), optional parameters are: maxTimeMS'},
      \ {'word': 'drop', 'menu': '()', 'info': 'drop the collection'},
      \ {'word': 'dropIndex', 'menu': '( index )', 'info': 'e.g. db.test.dropIndex( "indexName" ) or db.test.dropIndex( { "indexKey": 1 } )'},
      \ {'word': 'dropIndexes', 'menu': '()'},
      \ {'word': 'estimatedDocumentCount', 'menu': '( <optional params> )', 'info': 'estimate the document count using collection metadata, optional parameters are: maxTimeMS'},
      \ {'word': 'find', 'menu': '( [query], [fields] )', 'info': 'query is an optional query filter. fields is optional set of fields to return.'},
      \ {'word': 'findOne', 'menu': '( [query], [fields], [options], [readConcern] )'},
      \ {'word': 'findOneAndDelete', 'menu': '( filter, <optional params> )', 'info': 'delete first matching document, optional parameters are: projection, sort, maxTimeMS'},
      \ {'word': 'findOneAndReplace', 'menu': '( filter, replacement, <optional params> )', 'info': 'replace first matching document, optional parameters are: projection, sort, maxTimeMS, upsert, returnNewDocument'},
      \ {'word': 'findOneAndUpdate', 'menu': '( filter, <update object or pipeline>, <optional params> )', 'info': 'update first matching document, optional parameters are: projection, sort, maxTimeMS, upsert, returnNewDocument'},
      \ {'word': 'getDB', 'menu': '()', 'info': 'get DB object associated with collection'},
      \ {'word': 'getIndexes', 'menu': '()'},
      \ {'word': 'getPlanCache', 'menu': '()', 'info': 'get query plan cache associated with collection'},
      \ {'word': 'getShardDistribution', 'menu': '()', 'info': 'prints statistics about data distribution in the cluster'},
      \ {'word': 'getShardVersion', 'menu': '()', 'info': 'only for use with sharding'},
      \ {'word': 'getSplitKeysForChunks', 'menu': '( <maxChunkSize> )', 'info': 'calculates split points over all chunks and returns splitter function'},
      \ {'word': 'getWriteConcern', 'menu': '()', 'info': 'returns the write concern used for any operations on this collection, inherited from server/db if set'},
      \ {'word': 'insert', 'menu': '( obj )'},
      \ {'word': 'insertMany', 'menu': '( [objects], <optional params> )', 'info': 'insert multiple documents, optional parameters are: w, wtimeout, j'},
      \ {'word': 'insertOne', 'menu': '( obj, <optional params> )', 'info': 'insert a document, optional parameters are: w, wtimeout, j'},
      \ {'word': 'latencyStats', 'menu': '()', 'info': 'display operation latency histograms for this collection'},
      \ {'word': 'mapReduce', 'menu': '( mapFunction , reduceFunction , <optional params> )'},
      \ {'word': 'reIndex', 'menu': '()'},
      \ {'word': 'remove', 'menu': '( query )'},
      \ {'word': 'renameCollection', 'menu': '( newName , <dropTarget> )', 'info': 'renames the collection.'},
      \ {'word': 'replaceOne', 'menu': '( filter, replacement, <optional params> )', 'info': 'replace the first matching document, optional parameters are: upsert, w, wtimeout, j'},
      \ {'word': 'runCommand', 'menu': '( name , <options> )', 'info': 'runs a db command with the given name where the first param is the collection name'},
      \ {'word': 'save', 'menu': '( obj )'},
      \ {'word': 'setWriteConcern', 'menu': '( <write concern doc> )', 'info': 'sets the write concern for writes to the collection'},
      \ {'word': 'stats', 'menu': '( {scale: N, indexDetails: true/false, indexDetailsKey: <index key>, indexDetailsName: <index name>} )'},
      \ {'word': 'storageSize', 'menu': '()', 'info': 'includes free space allocated to this collection'},
      \ {'word': 'totalIndexSize', 'menu': '()', 'info': 'size in bytes of all the indexes'},
      \ {'word': 'totalSize', 'menu': '()', 'info': 'storage allocated for all data and indexes'},
      \ {'word': 'unsetWriteConcern', 'menu': '( <write concern doc> )', 'info': 'unsets the write concern for writes to the collection'},
      \ {'word': 'update', 'menu': '( query, <update object or pipeline>[, upsert_bool, multi_bool] )', 'info': 'instead of two flags, you can pass an object with fields: upsert, multi, hint'},
      \ {'word': 'updateMany', 'menu': '( filter, <update object or pipeline>, <optional params> )', 'info': 'update all matching documents, optional parameters are: upsert, w, wtimeout, j, hint'},
      \ {'word': 'updateOne', 'menu': '( filter, <update object or pipeline>, <optional params> )', 'info': 'update the first matching document, optional parameters are: upsert, w, wtimeout, j, hint'},
      \ {'word': 'validate', 'menu': '( <full> )', 'info': 'SLOW'},
      \]
