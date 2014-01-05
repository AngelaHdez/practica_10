var es = new EventSource('/chat-stream/:name');


es.onmessage = function(e){
    var chat = $("#chat");
    var content = $('<p>');
    content.append(e.data);
    chat.append(content);
    chat.append(content);
    var height = $("#chat").children().length;
    $("#chat").scrollTop(height * 1000);
};

$("#chat-submit").live("submit", function(e){
    var messages_box = $("#message");
    $.post('/chat', {
        message: $('#message').val()
    });
    messages_box.val('');
    messages_box.focus();
    e.preventDefault();
});