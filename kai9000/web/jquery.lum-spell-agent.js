(function ($) {
  'use strict';

  if (!$) throw new Error('jquery.lum-spell-agent requires jQuery');

  const defaults = {
    form: 'form',
    input: 'textarea, input[type="text"]',
    output: null,
    endpoint: '/api/lum/cast',
    includeRss: false,
    context: {},
    clearOnSend: true,
    disableWhileSending: true,
    render: null
  };

  function appendDefault($output, text, cssClass) {
    if (!$output || !$output.length) return;
    const $row = $('<div/>', { 'class': cssClass || 'lum-message' });
    $('<pre/>').text(text == null ? '' : String(text)).appendTo($row);
    $output.append($row);
  }

  function looksLikeSpell(text) {
    const value = String(text || '').trim();
    return /^(?:\/(?:cast|spell)\s+|CAST\s+|@LUM\s+)/i.test(value);
  }

  $.fn.lumSpellAgent = function (options) {
    const settings = $.extend(true, {}, defaults, options || {});

    return this.each(function () {
      const $root = $(this);
      const $form = $root.is('form') ? $root : $root.find(settings.form).first();
      const $input = $form.find(settings.input).first();
      const $output = settings.output ? $(settings.output) : $root.find('[data-lum-output]').first();

      if (!$form.length || !$input.length) {
        throw new Error('lumSpellAgent could not find a form and chat input');
      }

      $form.off('submit.lumSpellAgent').on('submit.lumSpellAgent', function (event) {
        event.preventDefault();

        const message = String($input.val() || '').trim();
        if (!message) return;

        const payload = {
          message: message,
          includeRss: Boolean(typeof settings.includeRss === 'function' ? settings.includeRss(message) : settings.includeRss),
          context: typeof settings.context === 'function' ? settings.context(message) : settings.context
        };

        const modeHint = looksLikeSpell(message) ? 'spell' : 'chat';
        $root.trigger('lum:before', [payload, modeHint]);
        appendDefault($output, message, 'lum-message lum-user');

        if (settings.clearOnSend) $input.val('');
        if (settings.disableWhileSending) $input.prop('disabled', true);

        $.ajax({
          url: settings.endpoint,
          method: 'POST',
          contentType: 'application/json; charset=utf-8',
          dataType: 'json',
          cache: false,
          data: JSON.stringify(payload)
        })
          .done(function (response) {
            if (typeof settings.render === 'function') {
              settings.render.call($root[0], response, $output);
            } else {
              appendDefault($output, response && response.output ? response.output : JSON.stringify(response, null, 2), 'lum-message lum-agent');
            }
            $root.trigger('lum:reply', [response]);
          })
          .fail(function (xhr) {
            const response = xhr.responseJSON || { ok: false, error: 'request_failed', status: xhr.status };
            appendDefault($output, response.error || 'Lum request failed', 'lum-message lum-error');
            $root.trigger('lum:error', [response, xhr]);
          })
          .always(function () {
            if (settings.disableWhileSending) $input.prop('disabled', false);
            $input.trigger('focus');
          });
      });
    });
  };

  $.lumSpellAgent = {
    looksLikeSpell: looksLikeSpell
  };
})(window.jQuery);
