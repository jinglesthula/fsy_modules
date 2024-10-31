(function() {
    'use strict';

    window.copyHire = function() {
        if ($('#records tr').length) {
            dceMessageBox.show('Clear setup first', 'error');
            return;
        }

        let context_id = prompt(`Enter the Hired Staff context_id`, 0)

        if (context_id === '0') {
            dceMessageBox.show(`You didn't enter a nice context_id`, 'error');
            return;
        }

        let tables = [
            { name: 'Hiring_Info', where: `context = ${context_id}` },
            { name: 'Hires_Availability', where: `context = ${context_id}` },
            { name: 'Availability_Week', where: `hires_availability = (select hires_availability_id from hires_availability where context = ${context_id})` },
            { name: 'Terms_Acceptance', where: `person = (select person from context where context_id = ${context_id} and program = (select value from cntl_value where control = 'CURRENT_FSY_PROGRAM'))` },
            { name: 'Context', where: `person = (select person from context where context_id = ${context_id})` },
        ]

        for (let table of tables) {
            $('#tableName').val(table.name)
            $('#tableName').closest('.formElement').next('.formElement').find('[type="button"]').trigger('click')
            $(`#${table.name}Row .condition`).trigger('click')
            $('#tableCondition').val(table.where)
            $('#conditionDiv').next('.ui-dialog-buttonpane').find('.ui-dialog-buttonset button:nth-child(2)').trigger('click')
        }

    }

    $('#footer-bottom').empty().html(`
      <button onclick="copyHire()">
        <span class="fas fa-user"></span> Copy Hire
      </button>
    `)
})();

/*
// ==UserScript==
// @name         Data Copy Tools
// @namespace    http://tampermonkey.net/
// @version      2024-04-23
// @description  try to take over the world!
// @author       You
// @match        https://localhost/o3/remote/setVar
// @icon         https://www.google.com/s2/favicons?sz=64&domain=undefined.localhost
// @grant        none
// @require      file://C:/code/fsy/ui/cf/o3/modules/ds/tampermonkey_scripts/setvar_data_copy_tools.js
// ==/UserScript==
*/

