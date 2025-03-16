let antTemplates;
let letter_code;
let letter_code_query = "";

$(document).ready(function () {
    let ant_plugin_templates = __ANT_PLUGIN_TEMPLATES__;
    let ant_missing_letter_code = false;

    letter_code = $("form#add_notice input#code").val();
    if (typeof letter_code !== 'undefined' && letter_code && letter_code.length > 0) {
        letter_code_query = "&letter_code=" + letter_code;
    }

    // Load modals
    $("body#tools_letter div#messages").after(`
        __ANT_PLUGIN_MODAL1__
    `);

    $("body#tools_letter div#toolbar div.btn-group").after(`
<div class="btn-group">
<button class="btn btn-default dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false">Advanced Notice Templates` + (letter_code ? " (" + letter_code + ")" : "") + `</button>
<ul class="dropdown-menu">
    <li><a class="dropdown-item" href="#antSetTemplate" data-bs-toggle="modal" data-bs-target="#antSetTemplate">Modify templates</a></li>
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
        $("input.antAcceptChanges:not(:disabled)").prop("checked", true);
    });
    $("a#antSelectNone").on("click", function () {
        $("input.antAcceptChanges:not(:disabled)").prop("checked", false);
    });
    $("a#antFreezeAll").on("click", function () {
        $("input.antFreezeNotice").prop("checked", true).trigger("change");
    });
    $("a#antFreezeNone").on("click", function () {
        $("input.antFreezeNotice").prop("checked", false).trigger("change");
    });
    $(document).on("change", "input.antFreezeNotice", function () {
        if (!$(this).is(':checked')) {
            $(this).closest('tr').find('input.antAcceptChanges').prop("disabled", false);
        } else {
            $(this).closest('tr').find('input.antAcceptChanges').prop("disabled", true);
        }
    });

    $("button#antConfirmHeader, button#antConfirmFooter").on("click", function () {
        let postData = [];
        let branchcode = $("form#selectlibrary select#branch").find(":selected").val();
        if (branchcode === '*' || typeof branchcode === 'undefined' || branchcode && branchcode.length === 0) {
            branchcode = '';
        }
        $("input.antAcceptChanges").each(function (el) {
            let changes_accepted = $(this).is(":checked");
            let freeze_toggled = $(this).closest("tr").find("input.antFreezeNotice").is(":checked") !== $(this).closest("tr").find("input.antNoticeWasFrozen").is(":checked");
            if (changes_accepted || freeze_toggled) {
                postData.push({
                    branchcode: branchcode,
                    code: $(this).attr("data-antCode"),
                    do_not_modify: !changes_accepted,
                    freeze: $(this).closest("tr").find("input.antFreezeNotice").is(":checked"),
                    lang: $(this).attr("data-antLang"),
                    message_transport_type: $(this).attr("data-antMtt"),
                });
            }
        });

        antModalReset();
        $.ajax({
            url: "/api/v1/contrib/advanced-notice-templates/templates/modifiable",
            type: "POST",
            dataType: "json",
            data: JSON.stringify(postData),
            contentType: "application/json; charset=utf-8",
            success: function (data) {
                antModalSuccess(antModalTemplatesModified(data), false);
                antReloadAjax();
            },
            error: function (data) {
                console.log(JSON.stringify(data));
                antModalError(JSON.stringify(data));
                antReloadAjax();
            }
        });
        function antReloadAjax() {
            $.ajax({
                url: "/api/v1/contrib/advanced-notice-templates/templates/modifiable?branchcode=" + branchcode + letter_code_query,
                type: "GET",
                dataType: "json",
                success: function (data) {
                    antPopulateModalWithTemplates(data);
                    antModalSuccess();
                },
                error: function (data) {
                    console.log(JSON.stringify(data));
                    let error_message = JSON.stringify(data);
                    if (data.status === 404) {
                        error_message = "No modifiable notice templates found";
                    }
                    antModalError(error_message);
                }
            });
        }
    })

    const antSetTemplate = document.getElementById("antSetTemplate");
    antSetTemplate.addEventListener("show.bs.modal", event => {
        antModalReset();
        let branchcode = $("form#selectlibrary select#branch").find(":selected").val();
        if (branchcode === '*' || typeof branchcode === 'undefined' || branchcode && branchcode.length === 0) {
            branchcode = '';
        }
        $.ajax({
            url: "/api/v1/contrib/advanced-notice-templates/templates/modifiable?branchcode=" + branchcode + letter_code_query,
            type: "GET",
            dataType: "json",
            success: function (data) {
                antPopulateModalWithTemplates(data);
                antModalSuccess();
            },
            error: function (data) {
                console.log(JSON.stringify(data));
                let error_message = JSON.stringify(data);
                if (data.status === 404) {
                    error_message = "No modifiable notice templates found";
                }
                antModalError(error_message);
            }
        });
    });
});

function antModalError(error, errorObj) {
    if (error && error.length) {
        $("div#antError").show();
        $("div#antError").html(error);
    }
    $("#antConfirmHeader").prop("disabled", true);
    $("#antConfirmFooter").prop("disabled", true);
    $("div#antLoader").hide();
}
function antModalReset() {
    $("div#antError").hide();
    $("div#antLoader").show();
    $("div#antSuccess").hide();
    if (letter_code) {
        $("span.antLetterCode").html(" | " + letter_code);
    } else {
        $("span.antLetterCode").html("");
    }
    $("tbody#antTemplateResultsBody").html("");
    $("#antConfirmHeader").prop("disabled", false);
    $("#antConfirmFooter").prop("disabled", false);
}
function antModalSuccess(success, hide = true) {
    if (success && success.length) {
        $("div#antSuccess").show();
        $("div#antSuccess").html(success);
    }
    if (hide) {
        $("div#antLoader").hide();
    }
}
function antModalTemplatesModified(data) {
    if (data.status === 404) {
        $("#antConfirmHeader").prop("disabled", true);
        $("#antConfirmFooter").prop("disabled", true);
    } else {
        $("#antConfirmHeader").prop("disabled", false);
        $("#antConfirmFooter").prop("disabled", false);
    }
    let modified_html = "";
    if (data.modified.length > 0) {
        modified_html += "<h3>Modified</h3><ul>";
        $.each(data.modified, function (modified, letter) {
            modified_html += '<li>' + letter.code + ' (' + letter.message_transport_type + ', language: ' + letter.lang + ') </li>';
        });
        modified_html += '</ul>';
    }

    if (data.not_modified.length > 0) {
        modified_html += "<h3>Unmodified</h3><ul>";
        $.each(data.not_modified, function (modified, letter) {
            modified_html += '<li>' + letter.code + ' (' + letter.message_transport_type + ', language: ' + letter.lang + ') </li>';
        });
        modified_html += '</ul>';
    }
    return modified_html;
}

function antPopulateModalWithTemplates(letters) {
    $.each(letters, function (letter_code, letter) {
        $.each(letter, function (i, template) {
            let disabled_checkbox = "";
            let checked_checkbox = ""
            if (template.frozen) {
                disabled_checkbox = ' disabled="disabled"';
                checked_checkbox = ' checked="checked"';
            }
            let accept_input_el = `<input type="checkbox" class="antAcceptChanges" data-antCode="` + letter_code + `" data-antLang="` + template.lang + `" data-antMtt="` + template.message_transport_type + `"` + disabled_checkbox + ` />`;
            let freeze_input_el = `<input type="checkbox" class="antFreezeNotice" data-antCode="` + letter_code + `" data-antLang="` + template.lang + `" data-antMtt="` + template.message_transport_type + `"` + checked_checkbox + ` /><input style="display:none;" type="checkbox" class="antNoticeWasFrozen" data-antCode="` + letter_code + `" data-antLang="` + template.lang + `" data-antMtt="` + template.message_transport_type + `"` + checked_checkbox + ` />`;
            $("tbody#antTemplateResultsBody").append(`
                <tr><td>` + accept_input_el + `</td><td>` + freeze_input_el + `</td><td>` + letter_code + `</td><td>` + template.lang + `</td><td>` + template.message_transport_type + `</td><td><span class="antTitle"></span><span class="antTitleNew">` + $("<div/>").text(template.new_template.title).html() + `</span><span class="antTitleOld">` + $("<div/>").text(template.old_template.title).html() + `</span></td><td><span class="antContent"><span class="antContentNew">` + $("<div/>").text(template.new_template.content).html() + `</span><span class="antContentOld">` + $("<div/>").text(template.old_template.content).html() + `</span></td>
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