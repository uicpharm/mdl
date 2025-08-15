# Authentication Callback

This page receives the callback from your authentication provider so
that you can copy the token to your clipboard.

<div style="margin-top: 10vh; text-align: center;">
   <code v-if="code" style="padding: 15px; margin: 20px;">{{ code }}</code>
   <button v-if="code" @click="copyToClipboard()">Copy Code</button>
   <div v-if="!code">No code has been provided.</div>
</div>

<script setup>
import { onMounted, ref } from 'vue';

const code = ref('');

onMounted(() => {
   const search = window.location.search;
   const urlParams = new URLSearchParams(search);
   code.value = urlParams.get('code') || '';
});

async function copyToClipboard() {
   await navigator.clipboard.writeText(code.value);
}
</script>
