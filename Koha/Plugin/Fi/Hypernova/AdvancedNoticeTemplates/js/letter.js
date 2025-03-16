let antTemplates;

$(document).ready(function () {
    let ant_plugin_templates = __ANT_PLUGIN_TEMPLATES__;
    let ant_missing_letter_code = false;

    // Load modals
    $("body#tools_letter div#messages").after(`
        __ANT_PLUGIN_MODAL1__
    `);

    $("body#tools_letter div#toolbar div.btn-group").after(`
<div class="btn-group">
<button class="btn btn-default dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">Advanced Notice Templates</button>
<ul class="dropdown-menu">
    <li><a class="dropdown-item" href="#antSetTemplate" data-bs-toggle="modal" data-bs-target="#antSetTemplate">Set default plugin templates</a></li>
</ul>
</div>
    `);
    $("table#lettert tr td:nth-child(3)").each(function () {
        if (!ant_plugin_templates.includes($(this).html())) {
            $(this).css("color", "red");
            ant_missing_letter_code = true;
        }
    });
    if (ant_missing_letter_code) {
        $("div#lettert_wrapper").after(`
            <div class="antMissingTemplateWarning">Red LETTER_CODE indicates a missing Advanced Notice Templates template. Plugin author should add the missing LETTER_CODE to the plugin's template repository, after which the maintainer of this Koha installation should upgrade the Advanced Notice Templates plugin.</div>
            `);
    }

    $("a#antSelectAll").on("click", function () {
        $("input.antAcceptChanges").prop("checked", true);
    });
    $("a#antSelectNone").on("click", function () {
        $("input.antAcceptChanges").prop("checked", false);
    });

    $("button#antConfirmHeader, button#antConfirmFooter").on("click", function () {
        let postData = [];
        let branchcode = $("form#selectlibrary select#branch").find(":selected").val();
        if (branchcode === '*' || typeof branchcode === 'undefined' || branchcode && branchcode.length === 0) {
            branchcode = '';
        }
        $("input.antAcceptChanges:checked").each(function (el) {
            postData.push({
                branchcode: branchcode,
                code: $(this).attr("data-antCode"),
                lang: $(this).attr("data-antLang"),
                message_transport_type: $(this).attr("data-antMtt"),
            });
        });
        antModalReset();
        $.ajax({
            url: "/api/v1/contrib/advanced-notice-templates/templates/modifiable",
            type: "POST",
            dataType: "json",
            data: JSON.stringify(postData),
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                antModalSuccess(data.responseText);
            },
            error: function (data) {
                console.log(data);
                antModalError(data.responseText);
            }
        });
    })

    const antSetTemplate = document.getElementById("antSetTemplate");
    antSetTemplate.addEventListener("show.bs.modal", event => {
        antModalReset();
        let branchcode = $("form#selectlibrary select#branch").find(":selected").val();
        if (branchcode === '*' || typeof branchcode === 'undefined' || branchcode && branchcode.length === 0) {
            branchcode = '';
        }
        $.ajax({
            url: "/api/v1/contrib/advanced-notice-templates/templates/modifiable?branchcode=" + branchcode,
            type: "GET",
            dataType: "json",
            success: function (data) {
                antPopulateModalWithTemplates(data);
                antModalSuccess(data.responseText);
            },
            error: function (data, text) {
                console.log(data);
                antModalError(data.responseText);
            }
        });
    });
});

function antModalError(error) {
    if (error && error.length) {
        $("div#antError").show();
        $("div#antError").html(error);
    }
    $("div#antLoader").hide();
}
function antModalReset() {
    $("div#antError").hide();
    $("div#antLoader").show();
    $("div#antSuccess").hide();
    $("tbody#antTemplateResultsBody").html("");
}
function antModalSuccess(success) {
    if (success && success.length) {
        $("div#antSuccess").show();
        $("div#antSuccess").html(success);
    }
    $("div#antLoader").hide();
}

function antPopulateModalWithTemplates(letters) {
    $.each(letters, function (letter_code, letter) {
        $.each(letter, function (i, template) {
            let accept_input_el = `<input type="checkbox" class="antAcceptChanges" checked="checked" data-antCode="` + letter_code + `" data-antLang="` + template.lang + `" data-antMtt="` + template.message_transport_type + `" />`;
            $("tbody#antTemplateResultsBody").append(`
                <tr><td>`+ accept_input_el + `</td><td>` + letter_code + `</td><td>` + template.lang + `</td><td>` + template.message_transport_type + `</td><td><span class="antTitle"></span><span class="antTitleNew">` + $("<div/>").text(template.new_template.title).html() + `</span><span class="antTitleOld">` + $("<div/>").text(template.old_template.title).html() + `</span></td><td><span class="antContent"><span class="antContentNew">` + $("<div/>").text(template.new_template.content).html() + `</span><span class="antContentOld">` + $("<div/>").text(template.old_template.content).html() + `</span></td>
            `);
        });
    });
    $("tbody#antTemplateResultsBody tr").prettyTextDiff({
        cleanup: true,
        originalContainer: '.antTitleOld',
        changedContainer: '.antTitleNew',
        diffContainer: '.antTitle'
    });
    $("tbody#antTemplateResultsBody tr").prettyTextDiff({
        cleanup: true,
        originalContainer: '.antContentOld',
        changedContainer: '.antContentNew',
        diffContainer: '.antContent'
    });
}