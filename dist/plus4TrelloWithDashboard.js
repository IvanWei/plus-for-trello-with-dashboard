(function() {
  var appendElement, authenticationFailure, authenticationSuccess, boardMenuParent, boardParent, db, flatten, getBoards, getMembersByBoardId, listData, listMenuParent, listParent, newMenuListTemplate, rejectBoard, rejectList, resolveBoard, resolveList, selectedList, subTitle, submit, syncBoard, syncList, title, trelloLogin, trelloLogout;

  trelloLogin = $('#login');

  trelloLogout = $('#logout');

  submit = $('#submit');

  syncBoard = $('#sync-board');

  syncList = $('#sync-list');

  boardParent = "#menu-link-1";

  boardMenuParent = "" + boardParent + " + .pure-menu-children";

  listParent = "#menu-link-2";

  listMenuParent = ".trello-list tbody";

  title = "#main > .header > h1";

  subTitle = "#main > .header > h2";

  selectedList = [];

  listData = null;

  db = {};

  authenticationSuccess = function(cb) {
    var token;
    token = Trello.token();
    Trello.setToken(token);
    $('#login').remove();
    return cb();
  };

  authenticationFailure = function() {
    console.error('Failed authentication, please login again.');
  };

  appendElement = function(targetElement, newElement) {
    return $(targetElement).append(newElement);
  };

  newMenuListTemplate = function(target, name, id, index) {
    switch (target) {
      case 'board':
        return '<li class="pure-menu-item"> <a href="javascript:void(0)" class="pure-menu-link" id="' + id + '" index="' + index + '">' + name + '</a> </li>';
      case 'list':
        return '<tr> <td><input type="checkbox" name="listGroup" id="' + id + '" value="' + index + '"></td> <td>' + (index + 1) + '</td> <td><label for="' + id + '" style="cursor: pointer;">' + name + '</label></td> </tr>';
    }
  };

  getBoards = function() {
    $(boardMenuParent).empty();
    return Trello.get("/member/me/boards", {
      filter: "open"
    }, resolveBoard, rejectBoard);
  };

  resolveBoard = function(boards) {
    return _.forEach(boards, function(board, boardIndex) {
      if (!(board.name || board.id)) {
        console.error('Create board menu error.');
        return false;
      }
      appendElement(boardMenuParent, newMenuListTemplate('board', board.name, "board-" + boardIndex, boardIndex));
      return $("#board-" + boardIndex).click(function() {
        var targetBoard;
        boardIndex = $(this).attr("index");
        targetBoard = boards[boardIndex];
        $(listMenuParent).empty();
        $(title).text(targetBoard.name);
        $(subTitle).text('A subtitle for List name');
        Trello.get('/boards/' + targetBoard.id + '/lists', {
          filter: "open"
        }, resolveList, rejectList);
        return getMembersByBoardId(targetBoard.id);
      });
    });
  };

  rejectBoard = function(error) {
    return console.error("[API] Get board list was error.", error);
  };

  resolveList = function(lists) {
    listData = lists;
    _.forEach(lists, function(list, listIndex) {
      appendElement(listMenuParent, newMenuListTemplate('list', list.name, "list-" + listIndex, listIndex));
    });
    submit.text('查詢');
    $(".trello-list").removeClass('collapse');
  };

  rejectList = function() {
    return console.error("[API] Get lists were error.");
  };

  Trello.authorize({
    interactive: false,
    success: function() {
      return authenticationSuccess(function() {
        getBoards();
      });
    },
    error: authenticationFailure
  });

  trelloLogin.click(function() {
    Trello.deauthorize();
    return Trello.authorize({
      type: 'popup',
      name: 'Plus for Trello with dashboard Application',
      scope: {
        read: true
      },
      expiration: 'never',
      success: function() {
        return authenticationSuccess(function() {
          getBoards();
        });
      },
      error: authenticationFailure
    });
  });

  trelloLogout.click(function() {
    Trello.deauthorize();
  });

  syncBoard.click(function() {
    getBoards();
  });

  $(boardParent).click(function() {
    $(boardParent).parent().addClass('active');
    $(listParent).parent().removeClass('active');
  });

  $(boardParent).blur(function() {
    setTimeout(function() {
      return $(boardParent).parent().removeClass('active');
    }, 200);
  });

  submit.click(function() {
    var currentList, index, promiseArr, tableCotentEl;
    if (!db.membersDB) {
      return console.warn('Board data is undefined, please choose a board.');
    }
    if (submit.text() === '重新查詢') {
      $(".trello-list").removeClass('collapse');
      submit.text('查詢');
      return;
    }
    tableCotentEl = '.comment-card-list tbody';
    index = 0;
    promiseArr = [];
    selectedList = [];
    currentList = $("" + listMenuParent + " input[type='checkbox']:checked");
    $(tableCotentEl).empty();
    _.forEach(currentList, function(list) {
      var currentListData;
      currentListData = listData[list.value];
      selectedList.push({
        id: currentListData.id,
        name: currentListData.name
      });
    });
    _.forEach(selectedList, function(selectedObj) {
      promiseArr.push(new Promise(function(resolve, reject) {
        return Trello.get('/list/' + selectedObj.id + '/cards', {
          actions: "commentCard,memberJoinedTrello"
        }, function(results) {
          return resolve(results, function(error) {
            return reject("" + selectedObj.id + " query was error, error message: ", error);
          });
        });
      }));
    });
    return Promise.all(promiseArr).then((function(results) {
      var cardData, commentCardData, filter;
      console.log("results:: ", results);
      if (typeof db.membersDB === 'undefined') {
        console.error('membersDB isn\'t existing.');
        return;
      }
      results = flatten(results);
      commentCardData = [];
      cardData = _.map(results, function(result) {
        var data;
        _.forEach(result.actions, function(commend) {
          var timeInfo, useTimeData;
          useTimeData = commend.data.text.match(/\s(-|)[0-9]+(.[0-9]+|)\/(-|)[0-9]+(.[0-9]+|)/, '');
          timeInfo = [];
          if (!!useTimeData) {
            timeInfo = useTimeData[0].split('/');
          }
          return commentCardData.push({
            date: new Date(commend.date).format('yyyy-MM-dd<br>HH:mm:ss'),
            id: commend.id,
            createUserId: commend.idMemberCreator,
            spentTime: timeInfo.length === 0 ? 'undefined' : Number(timeInfo[0]),
            totalTime: timeInfo.length === 0 ? 'undefined' : Number(timeInfo[1]),
            cardId: commend.data.card.id
          });
        });
        data = {
          id: result.id,
          name: result.name,
          shortUrl: result.shortUrl,
          sort: result.idShort,
          lastUpdate: result.dateLastActivity,
          taskUser: result.idMembers[0]
        };
        return data;
      });
      if (typeof db.cards === 'undefined') {
        db.cards = TaffyDB4Trello.create(cardData);
      } else {
        db.cards.merge(cardData, ['id']);
      }
      if (typeof db.commends === 'undefined') {
        db.commends = TaffyDB4Trello.create(commentCardData);
      } else {
        db.commends.merge(commentCardData, ['date']);
      }
      filter = _.map(results, function(result) {
        return result.id;
      }, []);
      db.cards().join(db.commends(), ['id', '===', 'cardId']).join(db.membersDB(), ['createUserId', '===', 'id']).filter({
        cardId: filter
      }).order('date desc').callback(function() {
        _.forEach(this.get(), function(result) {
          var content;
          if (result.spentTime === 0 || result.spentTime === 'undefined') {
            return;
          }
          index++;
          content = "<tr>\n  <td>" + index + "</td>\n  <td>" + result.date + "</td>\n  <td><a href='" + result.shortUrl + "'>" + result.name + "</td>\n  <td>" + result.fullName + "</td>\n  <td>" + result.spentTime + "</td>\n</tr>";
          appendElement(tableCotentEl, content);
        });
        $(".trello-list").addClass('collapse');
        return submit.text('重新查詢');
      });
    }), function(reason) {
      console.error("[API] Get card detail was error.", reason);
    });
  });

  flatten = function(arr) {
    return _.flattenDeep(arr);
  };

  Date.prototype.format = function(format) {
    var date, day, hours, minutes, month, seconds, year;
    date = this;
    day = date.getDate();
    month = date.getMonth() + 1;
    year = date.getFullYear();
    hours = date.getHours();
    minutes = date.getMinutes();
    seconds = date.getSeconds();
    if (!format) {
      format = 'MM/dd/yyyy';
    }
    format = format.replace('MM', month.toString().replace(/^(\d)$/, '0$1'));
    if (format.indexOf('yyyy') > -1) {
      format = format.replace('yyyy', year.toString());
    } else if (format.indexOf('yy') > -1) {
      format = format.replace('yy', year.toString().substr(2, 2));
    }
    format = format.replace('dd', day.toString().replace(/^(\d)$/, '0$1'));
    if (format.indexOf('t') > -1) {
      if (hours > 11) {
        format = format.replace('t', 'pm');
      } else {
        format = format.replace('t', 'am');
      }
    }
    if (format.indexOf('HH') > -1) {
      format = format.replace('HH', hours.toString().replace(/^(\d)$/, '0$1'));
    }
    if (format.indexOf('hh') > -1) {
      if (hours > 12) {
        hours -= 12;
      }
      if (hours === 0) {
        hours = 12;
      }
      format = format.replace('hh', hours.toString().replace(/^(\d)$/, '0$1'));
    }
    if (format.indexOf('mm') > -1) {
      format = format.replace('mm', minutes.toString().replace(/^(\d)$/, '0$1'));
    }
    if (format.indexOf('ss') > -1) {
      format = format.replace('ss', seconds.toString().replace(/^(\d)$/, '0$1'));
    }
    return format;
  };

  getMembersByBoardId = function(boardId) {
    return Trello.get("/boards/" + boardId + "/members", {}, function(results) {
      if (typeof db.membersDB === "undefined") {
        return db.membersDB = TaffyDB4Trello.create(results);
      } else {
        return db.membersDB.merge(results, ['id']);
      }
    }, function(error) {
      return console.error("Somthing wrong: ", error);
    });
  };

}).call(this);
