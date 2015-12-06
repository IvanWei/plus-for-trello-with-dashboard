trelloLogin = $('#login')
trelloLogout = $('#logout')
submit = $('#submit')
syncBoard = $('#sync-board')
syncList = $('#sync-list')
boardParent = "#menu-link-1"
boardMenuParent = "#{boardParent} + .pure-menu-children"
listParent = "#menu-link-2"
listMenuParent = ".trello-list tbody"

title = "#main > .header > h1"
subTitle = "#main > .header > h2"
selectedList = [] # 選取的 List id
listData = null
db = {}

# =========================== #
#       Local function        #
# =========================== #
authenticationSuccess = (cb) ->
  token = Trello.token()
  Trello.setToken(token)
  $('#login').remove()
  return cb()

authenticationFailure = ->
  console.error 'Failed authentication'
  return

appendElement = (targetElement, newElement) -> return $(targetElement).append newElement

newMenuListTemplate = (target, name, id, index) ->
  switch target
    when 'board'
      return '<li class="pure-menu-item">
        <a href="javascript:void(0)" class="pure-menu-link" id="' + id + '" index="' + index + '">' + name + '</a>
        </li>'
    when 'list'
      return '<tr>
        <td><input type="checkbox" name="listGroup" id="' + id + '" value="' + index + '"></td>
        <td>' + (index + 1) + '</td>
        <td><label for="' + id + '" style="cursor: pointer;">' + name + '</label></td>
      </tr>'

getBoards = ->
  $(boardMenuParent).empty()
  Trello.get "/member/me/boards", {filter: "open"}, resolveBoard, rejectBoard

resolveBoard = (boards) ->
  _.forEach boards, (board, boardIndex) ->
    unless board.name || board.id
      console.error  'Create board menu error.'
      return false

    appendElement(boardMenuParent, newMenuListTemplate('board', board.name, "board-#{boardIndex}", boardIndex))
    $("#board-#{boardIndex}").click ->
      boardIndex = $(@).attr("index")
      targetBoard = boards[boardIndex]

      $(listMenuParent).empty()
      $(title).text targetBoard.name
      $(subTitle).text('A subtitle for List name')
      Trello.get '/boards/' + targetBoard.id + '/lists', {filter: "open"}, resolveList, rejectList

      getMembersByBoardId targetBoard.id

rejectBoard = (error) ->
  console.error "[API] Get board list was error.", error

resolveList = (lists) ->
  listData = lists
  _.forEach lists, (list, listIndex) ->
    appendElement(listMenuParent, newMenuListTemplate('list', list.name, "list-#{listIndex}", listIndex))
    return

  submit.text('查詢')
  $(".trello-list").removeClass('collapse')
  return

rejectList = ->
  console.error "[API] Get lists were error."

# =========================== #
#       UI use function       #
# =========================== #
# Check user's authorization
Trello.authorize
  interactive: false
  success: ->
    authenticationSuccess ->
      getBoards()
      return
  error: authenticationFailure

trelloLogin.click ->
  Trello.deauthorize()
  Trello.authorize
    type: 'popup'
    name: 'Plus for Trello with dashboard Application'
    scope:
      read: true
    expiration: 'never'
    success: ->
      authenticationSuccess ->
        getBoards()
        return
    error: authenticationFailure

trelloLogout.click ->
  Trello.deauthorize()
  return

syncBoard.click ->
  getBoards()
  return

$(boardParent).click ->
  $(boardParent).parent().addClass('active')
  $(listParent).parent().removeClass('active')
  return

$(boardParent).blur ->
  setTimeout ->
    $(boardParent).parent().removeClass('active')
  , 200
  return

submit.click ->
  return console.warn 'Board data is undefined, please choose a board.' unless db.membersDB
  if submit.text() is '重新查詢'
    $(".trello-list").removeClass('collapse')
    submit.text('查詢')
    return

  tableCotentEl = '.comment-card-list tbody'
  index = 0
  promiseArr = []
  selectedList = []
  currentList = $("#{listMenuParent} input[type='checkbox']:checked")

  $(tableCotentEl).empty()

  _.forEach currentList, (list) ->
    currentListData = listData[list.value]
    selectedList.push {id: currentListData.id, name: currentListData.name}
    return

  # console.log "currentListData:: ", selectedList

  _.forEach selectedList, (selectedObj) ->
    promiseArr.push new Promise((resolve, reject) ->
      Trello.get '/list/' + selectedObj.id + '/cards', {actions: "commentCard,memberJoinedTrello"}
      , (results) -> return resolve results
      , (error) -> return reject "#{selectedObj.id} query was error, error message: ", error
    )
    return

  Promise.all(promiseArr)
  .then ((results) ->
    console.log "results:: ", results
    if typeof db.membersDB is 'undefined'
      console.error 'membersDB isn\'t existing.'
      return

    results = flatten results
    # console.log "membersDB:: ", db.membersDB().get()
    # console.log "resultsAA::", results
    commentCardData = []

    cardData = _.map results, (result) ->
      _.forEach result.actions, (commend) ->
        useTimeData = commend.data.text.match(/\s(-|)[0-9]+(.[0-9]+|)\/(-|)[0-9]+(.[0-9]+|)/, '')
        timeInfo = []
        if !!useTimeData
          timeInfo = useTimeData[0].split('/')

        #   console.log "AAA:: ", if timeInfo[0] is 'undefined' then timeInfo[0] else Number timeInfo[0]
        # else
        #   console.log "BB:: " , commend.data.text

        commentCardData.push {
          date: new Date(commend.date).format('yyyy-MM-dd<br>HH:mm:ss')
          id: commend.id
          createUserId: commend.idMemberCreator
          spentTime: if timeInfo.length is 0 then 'undefined' else Number timeInfo[0]
          totalTime: if timeInfo.length is 0 then 'undefined' else Number timeInfo[1]
          cardId: commend.data.card.id
        }

      data =
        id: result.id
        name: result.name
        shortUrl: result.shortUrl
        sort: result.idShort
        lastUpdate: result.dateLastActivity
        taskUser: result.idMembers[0]

      return data

    if typeof db.cards is 'undefined'
      db.cards = TaffyDB4Trello.create(cardData)
    else
      db.cards.merge(cardData, ['id'])

    if typeof db.commends is 'undefined'
      db.commends = TaffyDB4Trello.create(commentCardData)
    else
      db.commends.merge(commentCardData, ['date'])

    filter = _.map results, (result) ->
      return result.id
    , []

    db.cards().join(db.commends(), ['id', '===', 'cardId']).join(db.membersDB(), ['createUserId', '===', 'id'])
    .filter(cardId: filter).order('date desc').callback ->
      # console.log "res:: ", @get()
      _.forEach @get(), (result) ->
        return if result.spentTime is 0 || result.spentTime is 'undefined'
        index++
        content = """
          <tr>
            <td>#{index}</td>
            <td>#{result.date}</td>
            <td><a href='#{result.shortUrl}'>#{result.name}</td>
            <td>#{result.fullName}</td>
            <td>#{result.spentTime}</td>
          </tr>
        """
        appendElement(tableCotentEl, content)
        return

      $(".trello-list").addClass('collapse')
      submit.text('重新查詢')

    return
  ), (reason) ->
    console.error "[API] Get card detail was error.", reason
    return

# Todo 轉換，移至另一個檔案

flatten = (arr) -> return _.flattenDeep arr
Date::format = (format) ->
  date = this
  day = date.getDate()
  month = date.getMonth() + 1
  year = date.getFullYear()
  hours = date.getHours()
  minutes = date.getMinutes()
  seconds = date.getSeconds()
  if !format
    format = 'MM/dd/yyyy'
  format = format.replace('MM', month.toString().replace(/^(\d)$/, '0$1'))
  if format.indexOf('yyyy') > -1
    format = format.replace('yyyy', year.toString())
  else if format.indexOf('yy') > -1
    format = format.replace('yy', year.toString().substr(2, 2))
  format = format.replace('dd', day.toString().replace(/^(\d)$/, '0$1'))
  if format.indexOf('t') > -1
    if hours > 11
      format = format.replace('t', 'pm')
    else
      format = format.replace('t', 'am')
  if format.indexOf('HH') > -1
    format = format.replace('HH', hours.toString().replace(/^(\d)$/, '0$1'))
  if format.indexOf('hh') > -1
    if hours > 12
      hours -= 12
    if hours == 0
      hours = 12
    format = format.replace('hh', hours.toString().replace(/^(\d)$/, '0$1'))
  if format.indexOf('mm') > -1
    format = format.replace('mm', minutes.toString().replace(/^(\d)$/, '0$1'))
  if format.indexOf('ss') > -1
    format = format.replace('ss', seconds.toString().replace(/^(\d)$/, '0$1'))
  return format

# Trello
getMembersByBoardId = (boardId) ->
  Trello.get "/boards/#{boardId}/members", {}
    , (results) ->
      if typeof db.membersDB is "undefined"
        db.membersDB = TaffyDB4Trello.create results
      else
        db.membersDB.merge(results, ['id'])

      # console.log "reuslts:: ", db.membersDB().order("fullName").get()
    , (error) ->
      console.error "Somthing wrong: ", error
