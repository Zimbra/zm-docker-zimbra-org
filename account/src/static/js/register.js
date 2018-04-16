$(function (){
    $('#userForm').submit('click', function(event){
        var userName = $('#userName').val();
        userName = userName.replace("@bc.lonnin.me", "");
        $('#userName').val(userName + "@bc.lonnin.me");
    });
});
